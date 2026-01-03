//
//  InterruptType.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 03/01/26.
//

enum InterruptType {
    case joypad
    
    var bitMask: UInt8 {
        switch self {
            case .joypad:
                0x10
        }
    }
}
