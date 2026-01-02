//
//  CartridgeType.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 02/01/26.
//

enum CartridgeType {
    case none // 0x00
    case mbc1 // 0x01, 0x02, 0x03
    case mbc2 // 0x05, 0x06
    case mbc3 // 0x0F ... 0x13
    case mbc5 // 0x19 ... 0x1E
    case unknown
}
