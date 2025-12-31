//
//  Cartridge.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

import Foundation

final class Cartridge {
    var rom: [UInt8]
    
    init(romData: Data) {
        self.rom = [UInt8](romData)
    }
    
    @inline(__always)
    func read(_ address: UInt16) -> UInt8 {
        let addr = Int(address)
        
        if addr < rom.count {
            return rom[addr]
        }
        
        return 0xFF
    }
    
    @inline(__always)
    func write(address: UInt16, value: UInt8) {  }
    
    struct HeaderInfo {
        let title: String
        let type: UInt8
        let romSize: UInt8
    }
    
    @inline(__always)
    func parseHeader() -> HeaderInfo {
        let titleBytes = rom[0x134 ... 0x142].filter { $0 != 0 }
        let title = String(bytes: titleBytes, encoding: .ascii) ?? "Unknown"
        
        let typeRom = rom[0x147]
        let sizeRom = rom[0x148]
                        
        return HeaderInfo(title: title, type: typeRom, romSize: sizeRom)
    }
}
