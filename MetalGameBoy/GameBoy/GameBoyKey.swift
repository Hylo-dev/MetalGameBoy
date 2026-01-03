//
//  GameBoyKey.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 03/01/26.
//

enum GameBoyKey {
    case right
    case left
    case up
    case down
    case a
    case b
    case select
    case start
    
    var byte: UInt8 {
        switch self {
        case .right, .a:
            0x01
        case .left, .b:
            0x02
        case .up, .select:
            0x04
        case .down, .start:
            0x08
        }
    }
}
