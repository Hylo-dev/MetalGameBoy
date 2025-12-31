//
//  MetalGameBoyView.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 31/12/25.
//

import SwiftUI
import MetalKit

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#endif

struct MetalGameBoyView: ViewRepresentable {
    let gameboy: GameBoy // Riferimento al tuo emulatore
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Setup per macOS
    #if os(macOS)
    func makeNSView(context: Context) -> MTKView {
        createMetalView(context: context)
    }
    func updateNSView(_ nsView: MTKView, context: Context) {}
    typealias ViewRepresentable = NSViewRepresentable
    #endif

    func createMetalView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }

    // IL COORDINATOR: Il vero motore grafico
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalGameBoyView
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var texture: MTLTexture!
        
        // Dati dei vertici (un rettangolo che copre lo schermo)
        let vertexData: [Float] = [
            -1.0, -1.0,  0.0, 1.0, // V0: Basso-Sinistra
             1.0, -1.0,  1.0, 1.0, // V1: Basso-Destra
            -1.0,  1.0,  0.0, 0.0, // V2: Alto-Sinistra
             1.0,  1.0,  1.0, 0.0  // V3: Alto-Destra
        ]
        var vertexBuffer: MTLBuffer!

        init(_ parent: MetalGameBoyView) {
            self.parent = parent
            super.init()
            self.device = MTLCreateSystemDefaultDevice()
            self.commandQueue = device.makeCommandQueue()
            setupPipeline()
            setupTexture()
            setupBuffers()
        }
        
        func setupPipeline() {
            guard let library = device.makeDefaultLibrary() else { return }
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "basic_vertex")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "basic_fragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        func setupTexture() {
            let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 160, height: 144, mipmapped: false)
            textureDesc.usage = [.shaderRead]
            texture = device.makeTexture(descriptor: textureDesc)
        }
        
        func setupBuffers() {
            let dataSize = vertexData.count * MemoryLayout<Float>.size
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        // QUESTA FUNZIONE VIENE CHIAMATA 60 VOLTE AL SECONDO
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState else { return }
            
            // 1. Eseguiamo un frame del GameBoy!
            //    (Se vuoi puoi spostarlo in un thread separato, ma qui è sicuro e sincronizzato col VSync)
            parent.gameboy.runFrame()
            
            // 2. Aggiorniamo la texture GPU con i byte della RAM GameBoy (VELOCISSIMO)
            let region = MTLRegionMake2D(0, 0, 160, 144)
            texture.replace(region: region, mipmapLevel: 0, withBytes: parent.gameboy.frameBuffer, bytesPerRow: 160 * 4)
            
            // 3. Disegniamo a schermo
            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder?.setRenderPipelineState(pipelineState)
            renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentTexture(texture, index: 0)
            renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            renderEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
