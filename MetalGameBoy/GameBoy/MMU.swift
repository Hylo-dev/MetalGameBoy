//
//  MMU.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

import Foundation

final class MMU {
    private var memory: UnsafeMutablePointer<UInt8>
    private let capacity = 65536 // 64KB
    
    private var cartridge: Cartridge?
    private var ppu: PPU?
    
    unowned var timer: TimerGB!
    
    private var dmaDelay: Int = 0
    
    var actionButtons: UInt8 = 0x0F    // Start, Select, B, A
    var directionButtons: UInt8 = 0x0F // Down, Up, Left, Right
    
    var joyp: UInt8 = 0xFF // JOYP Reg
    
    init() {
        self.memory = UnsafeMutablePointer.allocate(capacity: capacity)
        self.memory.initialize(repeating: 0xFF, count: capacity)
    }
    
    deinit {
        self.memory.deallocate()
    }
    
    func load(
        cartridge: Cartridge,
        ppu      : PPU
    ) {
        self.cartridge = cartridge
        self.ppu       = ppu
    }
    
    @inline(__always)
    func readByte(_ address: UInt16) -> UInt8? {
        if self.dmaDelay > 0 {
            // HRAM is Only accessible in DMA delay
            if address >= 0xFF80 && address <= 0xFFFE {
                return self.memory[Int(address)]
            }
            
            return 0xFF
        }
        
        if address == 0xFF00 {
            var output = (self.joyp & 0xF0) | 0x0F
            
            // Buttons
            if (self.joyp & 0x20) == 0 {
                output &= self.actionButtons
            }
            
            // D-Pad
            if (self.joyp & 0x10) == 0 {
                output &= self.directionButtons
            }
            
            return output
        }
        
        if address == 0xFF04 { return timer.div }
        if address == 0xFF44 { return self.ppu!.lineY }
        
        switch address {
            
        case 0x0000...0x7FFF:
            return self.cartridge?.read(address) ?? 0xFF
            
        case 0x8000...0x9FFF:
            guard let ppu = self.ppu else { return 0xFF }
            return ppu.vram[Int(address - 0x8000)]
            
        case 0xA000...0xBFFF:
            return self.cartridge?.read(address) ?? 0xFF
            
        case 0xFE00...0xFE9F:
            guard let ppu = self.ppu else { return 0xFF }
            return ppu.oam[Int(address - 0xFE00)]
        
            
        default:
            return self.memory[Int(address)]
        }
    }
    
    @inline(__always)
    func writeByte(
        _ value: UInt8,
        in address: UInt16
    ) {
        if self.dmaDelay > 0 {
            // HRAM is Only accessible in DMA delay
            if address >= 0xFF80 && address <= 0xFFFE {
                self.memory[Int(address)] = value
            }
            
            return
        }
        
        // Write input mode
        if address == 0xFF00 {
            let oldBits = self.joyp & 0xCF
            let newSelection = value & 0x30
                
            self.joyp = oldBits | newSelection
            return
        }
        
        if address == 0xFF04 { self.timer.resetDiv(); return }
        if address == 0xFF44 { return }
        
        if address == 0xFF46 {
            performDMATransfer(value)
            return
        }
        
        if address >= 0xFE00 && address <= 0xFE9F {
            guard let ppu = self.ppu else { return }
            ppu.oam[Int(address - 0xFE00)] = value
            return
        }
        
        if address >= 0x8000 && address <= 0x9FFF {
            guard let ppu = self.ppu else { return }
            ppu.vram[Int(address - 0x8000)] = value
            return
        }
                
        if address >= 0x0000 && address <= 0x7FFF {
            self.cartridge?.write(address, value: value)
            return
        }
        
        self.memory[Int(address)] = value
    }
    
    private func performDMATransfer(_ value: UInt8) {
        let sourceBase = UInt16(value) << 8
        
        guard let ppu = self.ppu else { return }
                
        for i in 0..<160 {
            let sourceAddr = sourceBase + UInt16(i)
            let byte = readByte(sourceAddr) ?? 0
            ppu.oam[i] = byte
        }
        
        self.dmaDelay = 160
    }
    
    func tickDMA(_ cycles: Int) {
        if self.dmaDelay > 0 {
            self.dmaDelay -= cycles
            if self.dmaDelay < 0 { self.dmaDelay = 0 }
        }
    }

    func isDMAActive() -> Bool {
        return self.dmaDelay > 0
    }
    
    func requestInterrupt(_ type: InterruptType) {
        guard var currentIF = self.readByte(0xFF0F) else { return }
        
        currentIF = currentIF | type.bitMask
        
        self.writeByte(currentIF, in: 0xFF0F)
    }
}
