//
//  GameBoy.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

import Foundation

final class GameBoy {
    private let mmu: MMU
    private let cpu: CPU
    private let ppu: PPU
    private let timer: TimerGB
    
    init() {
        self.timer = TimerGB()
        
        self.mmu = MMU()
        self.mmu.timer = timer
        self.cpu = CPU(mmu: mmu)
        self.ppu = PPU(mmu: mmu)
    }
    
    var frameBuffer: UnsafeMutablePointer<UInt8> {
        self.ppu.frameBuffer
    }
    
    func boot(romData: Data) -> Bool {
        let cart = Cartridge(romData: romData)
        
        self.mmu.load(cartridge: cart, ppu: self.ppu)
        self.cpu.reset()
    
        return true
    }
        
    func runFrame() {
        let maxCycles = 70224
        var cyclesThisFrame = 0
        
        while cyclesThisFrame < maxCycles {
            let cycles = cpu.step()
            cyclesThisFrame += cycles
            
            self.ppu.step(cycles)
            self.timer.step(cycles)
        }
    }
    
    func keyUp(_ key: GameBoyKey) {
        switch key {
            case .right, .left, .up, .down:
                self.mmu.directionButtons |= key.byte
            
            case .a, .b, .select, .start:
                self.mmu.actionButtons |= key.byte
        }
        
        self.mmu.requestInterrupt(.joypad)
    }
    
    func keyDown(_ key: GameBoyKey) {
        switch key {
            case .right, .left, .up, .down:
                self.mmu.directionButtons &= ~key.byte
            
            case .a, .b, .select, .start:
                self.mmu.actionButtons &= ~key.byte
        }
        
        self.mmu.requestInterrupt(.joypad)
    }
}
