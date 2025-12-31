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
    
    weak var timer: TimerGB?
    
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
        if address == 0xFF04 { return timer!.div }
        if address == 0xFF00 { return 0xFF }
        if address == 0xFF44 { return self.ppu!.lineY }
        
        if address < 0x8000 || (address >= 0xA000 && address < 0xC000) {
            return self.cartridge!.read(address)
        }
        
        return memory[Int(address)]
    }
    
    @inline(__always)
    func writeByte(
        _ value: UInt8,
        in address: UInt16
    ) {
        
        if address == 0xFF04 {
            timer?.resetDiv()
            return
        }
        
        if address == 0xFF44 {
            return
        }
        
        if address < 0x8000 || (address >= 0xA000 && address < 0xC000) {
            cartridge?.write(address: address, value: value)
            return
        }
        
        memory[Int(address)] = value
    }
}
