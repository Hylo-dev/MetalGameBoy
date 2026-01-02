//
//  CPU.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

import Foundation
final class CPU {
    
    var a: UInt8 = 0 // Accumulator
    private(set) var f: UInt8 = 0 // Flags
    // bit 7: zero
    // bit 6: subtraction flag
    // bit 5: half carry flag
    // bit 4: carry flag
    
    // Generics
    private(set) var b: UInt8 = 0
    private(set) var c: UInt8 = 0
    private(set) var d: UInt8 = 0
    private(set) var e: UInt8 = 0
    private(set) var h: UInt8 = 0
    private(set) var l: UInt8 = 0
    
    // Special registers
    var sp: UInt16 = 0 // Stack pointer
    var pc: UInt16 = 0 // Program counter
    
    // Interrupt Master Enable
    var ime: Bool = false
    
    // Halted Condition
    var isHalted: Bool = false

    var mmu: MMU
    private lazy var decode: Decode = Decode(cpu: self)
    private lazy var alu: ALU = ALU(cpu: self)
    
    init(mmu: MMU) {
        self.mmu = mmu
    }
    
    // Virtual registers
    var af: UInt16 {
        get {
            return (UInt16(self.a) << 8) | UInt16(self.f)
        }
        
        set {
            self.a = UInt8((newValue >> 8) & 0xFF)
            self.f = UInt8(newValue & 0xF0)
        }
    }
    
    var bc: UInt16 {
        get {
            return (UInt16(self.b) << 8) | UInt16(self.c)
        }
        
        set {
            self.b = UInt8((newValue >> 8) & 0xFF)
            self.c = UInt8(newValue & 0xFF)
        }
    }
    
    var de: UInt16 {
        get {
            return (UInt16(self.d) << 8) | UInt16(self.e)
        }
        
        set {
            self.d = UInt8((newValue >> 8) & 0xFF)
            self.e = UInt8(newValue & 0xFF)
        }
    }
    
    var hl: UInt16 {
        get {
            return (UInt16(self.h) << 8) | UInt16(self.l)
        }
        
        set {
            self.h = UInt8((newValue >> 8) & 0xFF)
            self.l = UInt8(newValue & 0xFF)
        }
    }
    
    // MARK: - Step
    
    func step() -> Int {
        if self.mmu.isDMAActive() {
            self.mmu.tickDMA(4)
            return 4
        }
        
        if isHalted {
            if let ie = mmu.readByte(0xFFFF), let `if` = mmu.readByte(0xFF0F),
               (ie & `if`) > 0 {
                isHalted = false
                
            } else {
                return 4
            }
        }
        
        let interruptCycles = handleInterrupts()
        if interruptCycles > 0 {
            self.isHalted = false
            self.mmu.tickDMA(interruptCycles)
            return interruptCycles
        }
        
        guard let instruction = fetch() else { return 0 }
        
        let decoded = self.decode.execute(instruction)
        let cycles  = self.alu.execute(decoded)
        
        self.mmu.tickDMA(cycles)
        
        return cycles
    }
    
    func reset() {
        self.pc = 0x0100
                
        self.sp = 0xFFFE
                
        self.a = 0x01
        self.f = 0xB0
        self.b = 0x00
        self.c = 0x13
        self.d = 0x00
        self.e = 0xD8
        self.h = 0x01
        self.l = 0x4D
                
        self.ime = false
    }
    
    // MARK: - Fetch, Decode, Execute
    
    func fetch() -> UInt8? {
        let value = mmu.readByte(pc)
        
        self.pc &+= 1 // Gemini recomend this because management manualy overflow
        
        return value
    }
    
    func fetchHalfWord() -> UInt16? {
        guard let low = fetch(), let high = fetch() else { return nil }
                
        return (UInt16(high) << 8) | UInt16(low)
    }
    
    // MARK: - Handle
    
    func setFlag(value: Flag, _ on: Bool) {
        // 1 0 0 1  0 0 0 0
        // 0 1 0 0  0 0 0 0|
        
        // 1 0 0 1
        
        let mask: UInt8
        
        mask = switch (value) {
            case .zero       : 0x80
            case .subtraction: 0x40
            case .halfCarry  : 0x20
            case .carry      : 0x10
        }
        
        if on { self.f |= mask } else { self.f &= ~mask }
    }
    
    func getFlagStatus(value: Flag) -> Bool {
        
        // 1 1 1 1
        // 0 0 0 1 &
        // 0 0 0 1
        // >> 3
        // 0 0 0 1
        
        let mask: UInt8
        
        mask = switch (value) {
            case .zero       : 0x80
            case .subtraction: 0x40
            case .halfCarry  : 0x20
            case .carry      : 0x10
        }
        
        return (self.f & mask) != 0
    }
    
    func decodeRegister(_ code: UInt8) -> Target {
        return switch code {
            case 0: .b
            case 1: .c
            case 2: .d
            case 3: .e
            case 4: .h
            case 5: .l
            case 6: .hlPointer
            case 7: .a
            default: fatalError("Register non found")
        }
    }
    
    func getVal(_ target: Target) -> UInt8 {
        return switch target {
            case .a: a
            case .b: b
            case .c: c
            case .d: d
            case .e: e
            case .h: h
            case .l: l
            case .hlPointer: mmu.readByte(hl)!
        }
    }
    
    func setVal(
        _  value : UInt8,
        in target: Target
    ) {
        switch target {
            case .a: a = value
            case .b: b = value
            case .c: c = value
            case .d: d = value
            case .e: e = value
            case .h: h = value
            case .l: l = value
            case .hlPointer: mmu.writeByte(value, in: hl)
        }
    }
    
    // MARK: - Interrupt
    private func handleInterrupts() -> Int {
        guard self.ime else { return 0 }
        
        guard let ie   = self.mmu.readByte(0xFFFF),
              var `if` = self.mmu.readByte(0xFF0F)
        else { return 0 }
        
        // Control if exist interrupt
        if (ie & `if`) > 0 {
            
            for i in 0 ..< 5 {
                let mask: UInt8 = 1 << i
                
                let ieBit = ie   & mask
                let ifBit = `if` & mask
                
                if ieBit != 0 && ifBit != 0 {
                    self.ime = false
                    
                    `if` &= ~mask
                    
                    self.mmu.writeByte(`if`, in: 0xFF0F)
                    
                    pushWord(self.pc)
                    
                    switch i {
                        case 0: self.pc = 0x0040 // V-Blank
                        case 1: self.pc = 0x0048 // LCD STAT
                        case 2: self.pc = 0x0050 // Timer
                        case 3: self.pc = 0x0058 // Serial
                        case 4: self.pc = 0x0060 // Joypad
                        default: break
                    }
                    return 20
                }
            }
        }
        
        return 0
    }
    
    // MARK: - Stack Handler
    private func pushWord(_ value: UInt16) {
        let high = UInt8((value >> 8) & 0xFF)
        let low  = UInt8(value & 0xFF)
        
        self.sp -= 1
        mmu.writeByte(high, in: self.sp)
        
        self.sp -= 1
        mmu.writeByte(low, in: self.sp)
    }

}
