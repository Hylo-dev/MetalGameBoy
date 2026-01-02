//
//  Cartridge.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

import Foundation

final class Cartridge {
    private var rom: UnsafeMutablePointer<UInt8>
    private var romSize: Int
    private var currentBank: Int = 1
    private var cartType: CartridgeType = .none
    
    init(romData: Data) {
        self.romSize = romData.count
        
        self.rom = UnsafeMutablePointer.allocate(capacity: self.romSize)
        romData.copyBytes(to: self.rom, count: self.romSize)
        
        let typeByte = romSize >= 0x148 ? self.rom[0x147] : 0
        
        switch typeByte {
        case 0x00:
            self.cartType = .none
            
        case 0x01, 0x02, 0x03:
            self.cartType = .mbc1
            
        case 0x05, 0x06:
            self.cartType = .mbc2
            
        case 0x0F, 0x10, 0x11, 0x12, 0x13:
            self.cartType = .mbc3
            
        case 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E:
            self.cartType = .mbc5
            
        default: self.cartType = .unknown
        }
    }
    
    deinit { self.rom.deallocate() }
    
    @inline(__always)
    func read(_ address: UInt16) -> UInt8 {
        let addr = Int(address)
        
        if addr < 0x4000 {
            if addr >= self.romSize { return 0xFF }
            return self.rom[addr]
        }
                
        if addr < 0x8000 {
            let offsetAddr = (addr - 0x4000) + (self.currentBank * 0x4000)
            if offsetAddr >= self.romSize {
                return 0xFF
            }
            
            return self.rom[offsetAddr]
        }
        
        return 0xFF
    }
    
    @inline(__always)
    func write(_ address: UInt16, value: UInt8) {
        if self.cartType != .none && (address >= 0x2000 && address <= 0x3FFF) {
            var newBank = Int(value & 0x1F)
            
            if newBank == 0 {
                if self.cartType == .mbc1 || self.cartType == .mbc2 {
                    newBank = 1
                }
            }
            
            self.currentBank = newBank
        }
    }
    
//    struct HeaderInfo {
//        let title  : String
//        let type   : UInt8
//        let romSize: UInt8
//    }
    
//    @inline(__always)
//    func parseHeader() -> HeaderInfo {
//        let titleBytes = rom[0x134 ... 0x142].filter { $0 != 0 }
//        let title = String(bytes: titleBytes, encoding: .ascii) ?? "Unknown"
//
//        let typeRom = rom[0x147]
//        let sizeRom = rom[0x148]
//
//        return HeaderInfo(title: title, type: typeRom, romSize: sizeRom)
//    }
}
