import Foundation

final class PPU {
    private var counter: Int = 0
    private(set) var lineY: UInt8 = 0
    
    private var mmu: MMU
    
    // Buffer video: 160x144 pixel
    static let screenWidth = 160
    static let screenHeight = 144
    static let bytesPerPixel = 4
    
    let bufferSize = screenWidth * screenHeight * bytesPerPixel
    var frameBuffer: UnsafeMutablePointer<UInt8>
    
    // Variabile per limitare i log
    private var debugTimer = 0
    
    init (mmu: MMU) {
        self.mmu = mmu
        
        self.frameBuffer = UnsafeMutablePointer.allocate(capacity: bufferSize)
        self.frameBuffer.initialize(repeating: 255, count: bufferSize)
    }
    
    deinit {
        self.frameBuffer.deallocate()
    }
    
    func step(_ cycles: Int) {
        self.counter += cycles
        
        if self.counter >= 456 {
            self.counter -= 456
            
            if self.lineY < 144 {
                drawScanline()
            }
            
            self.lineY += 1
            
            if self.lineY == 144 {
                if var intFlag = self.mmu.readByte(0xFF0F) {
                    intFlag |= 0x01
                    self.mmu.writeByte(intFlag, in: 0xFF0F)
                }
            }
            
            if self.lineY > 153 {
                self.lineY = 0
                debugTimer += 1 // Conta i frame
            }
        }
    }
    
    @inline(__always)
    private func drawScanline() {
        let lcdc = mmu.readByte(0xFF40) ?? 0
        let scy = mmu.readByte(0xFF42) ?? 0
        let scx = mmu.readByte(0xFF43) ?? 0
        let bgPalette = mmu.readByte(0xFF47) ?? 0
       
        guard (lcdc & 0x80) != 0 else { return }
        
        let mapBase: UInt16 = (lcdc & 0x08) != 0 ? 0x9C00 : 0x9800
        let useUnsigned = (lcdc & 0x10) != 0
        
        let yPos = lineY &+ scy
        let mapRow = UInt16(yPos / 8)
        let tileRow = UInt16(yPos % 8)
        
        for x in 0..<160 {
            let xPos = UInt8(x) &+ scx
            let mapCol = UInt16(xPos / 8)
            let tileCol = UInt8(xPos % 8)
            
            let tileMapAddress = mapBase + mapRow * 32 + mapCol
            let tileIndex = mmu.readByte(tileMapAddress) ?? 0
            
            var tileAddress: UInt16
            if useUnsigned {
                tileAddress = 0x8000 + UInt16(tileIndex) * 16
            } else {
                let signedIndex = Int8(bitPattern: tileIndex)
                tileAddress = UInt16(Int(0x9000) + Int(signedIndex) * 16)
            }
            
            let byte1 = mmu.readByte(tileAddress + tileRow * 2) ?? 0
            let byte2 = mmu.readByte(tileAddress + tileRow * 2 + 1) ?? 0
            
            let bitIndex = 7 - Int(tileCol)
            let bitLow = (byte1 >> bitIndex) & 0x01
            let bitHigh = (byte2 >> bitIndex) & 0x01
            let colorId = (bitHigh << 1) | bitLow
            
            let realColorId = (bgPalette >> (colorId * 2)) & 0x03
            
            let color: (UInt8, UInt8, UInt8) = switch realColorId {
                case 0: (255, 255, 255)
                case 1: (170, 170, 170)
                case 2: (85, 85, 85)
                case 3: (0, 0, 0)
                default: (255, 255, 255)
            }
            
            let pixelIndex = (Int(lineY) * 160 + x) * 4
            frameBuffer[pixelIndex]     = color.0
            frameBuffer[pixelIndex + 1] = color.1
            frameBuffer[pixelIndex + 2] = color.2
            frameBuffer[pixelIndex + 3] = 255
        }
    }
}
