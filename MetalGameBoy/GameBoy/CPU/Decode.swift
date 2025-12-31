//
//  Decode.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 31/12/25.
//

struct Decode {
    
    unowned let cpu: CPU
    
    init(cpu: CPU) {
        self.cpu = cpu
    }
    
    func execute(_ address: UInt8) -> Instruction {
        let firstBlock  = (address >> 6) & 0b11
        let secondBlock = (address >> 3) & 0b111
        let thirdBlock  = address & 0b111
        
        if address == 0x10 {
            guard let _ = self.cpu.fetch() else { return .nop }
            return .stop
        }
        
        if let interrupt = controlInterrupt(address) {
            return interrupt
        }
        
        if address == 0xCB { return decodeCB() }
        
        if let specialAcc = controlSpecialAccumulator(address) {
            return specialAcc
        }
        
        if let highRam = controlHighRam(address) {
            return highRam
        }
        
        if let controlHL = controlHLIncDec(address) {
            return controlHL
        }
        
        if let controlLoad16 = controlLoad16(address) {
            return controlLoad16
        }
        
        if let controlArithmeticImm = controlArithmeticImm(address) {
            return controlArithmeticImm
        }
        
        if let controlArith16 = controlArithmetic16(address) {
            return controlArith16
        }
        
        if let controlJump = controlJump(address) {
            return controlJump
        }
        
        if let controlCallRet = controlCallRet(address) {
            return controlCallRet
        }
        
        if let controlStack = controlStack(address) {
            return controlStack
        }
        
        
        if firstBlock == 0 {
            
            switch thirdBlock {
                case 4:
                    let target = self.cpu.decodeRegister(secondBlock)
                    return .inc(target: target)
                
                case 5:
                    let target = self.cpu.decodeRegister(secondBlock)
                    return .dec(target: target)
                
                case 6:
                    guard let value = self.cpu.fetch() else { return .nop }
                    let target = self.cpu.decodeRegister(secondBlock)
                    return .loadImmediate(dest: target, value: value)
                
                case 7:
                    switch secondBlock {
                        case 0 : return .rotateA(type: .rlc)
                        case 1 : return .rotateA(type: .rrc)
                        case 2 : return .rotateA(type: .rl)
                        case 3 : return .rotateA(type: .rr)
                        case 4 : return .daa
                        case 5 : return .cpl
                        case 6 : return .scf
                        case 7 : return .ccf
                        default: return .nop
                    }
                
                case 3:
                    let isDec = (address & 0x08) != 0
                    let regIndex = secondBlock >> 1
                    
                    let target: Target16 = switch regIndex {
                        case 0 : .bc
                        case 1 : .de
                        case 2 : .hl
                        case 3 : .sp
                        default: .bc
                    }
                    return isDec ? .dec16(target: target) : .inc16(target: target)
                    
                    default: break
            }
        }
        
        if firstBlock == 1 {
            let dest = self.cpu.decodeRegister(secondBlock)
            let src  = self.cpu.decodeRegister(thirdBlock)
            
            if address == 0x76 { return .halt }
            return .load(to: dest, from: src)
        }
        
        if firstBlock == 2 {
            let src = self.cpu.decodeRegister(thirdBlock)
            
            return switch secondBlock {
                case 0 : .add(source: src)
                case 1 : .adc(source: src)
                case 2 : .sub(source: src)
                case 3 : .sbc(source: src)
                case 4 : .and(source: src)
                case 5 : .xor(source: src)
                case 6 : .or(source: src)
                case 7 : .cp(source: src)
                default: .nop
            }
        }
        
        return .nop
    }
    
    // MARK: - Handled Control Instructions
    
    private func controlInterrupt(_ address: UInt8) -> Instruction? {
        if address == 0xFB { return .ei   }
        if address == 0xF3 { return .di   }
        if address == 0xD9 { return .reti }
        
        return nil
    }
    
    private func controlSpecialAccumulator(_ address: UInt8) -> Instruction? {
        if address == 0x02 { return .ld_rr_a(target: .bc) }
        if address == 0x12 { return .ld_rr_a(target: .de) }
        
        if address == 0x0A { return .ld_a_rr(source: .bc) }
        if address == 0x1A { return .ld_a_rr(source: .de) }
        
        if address == 0xFA {
            guard let addr = self.cpu.fetchHalfWord() else { return .nop }
            return .ld_a_nn(addr: addr)
        }
        
        if address == 0xEA {
            guard let addr = self.cpu.fetchHalfWord() else { return .nop }
            return .ld_nn_a(addr: addr)
        }
        
        return nil
    }
    
    private func controlHighRam(_ address: UInt8) -> Instruction? {
        if address == 0xF0 {
            guard let instr = self.cpu.fetch() else { return .nop }
            return .ldh_a_n(n: instr)
        }
        
        if address == 0xE0 {
            guard let instr = self.cpu.fetch() else { return .nop }
            return .ldh_n_a(n: instr)
        }
        
        if address == 0xE2 { return .ldh_c_a }
        if address == 0xF2 { return .ldh_a_c }
        
        return nil
    }
    
    private func controlHLIncDec(_ address: UInt8) -> Instruction? {
        if address == 0x2A { return .ldi_a_hl } // Read (HL+)
        if address == 0x22 { return .ldi_hl_a } // Write (HL+)
        
        if address == 0x3A { return .ldd_a_hl } // Read (HL-)
        if address == 0x32 { return .ldd_hl_a } // Write (HL-)
        
        return nil
    }
    
    private func controlLoad16(_ address: UInt8) -> Instruction? {
        
        if address == 0xF8 {
            guard let addr = self.cpu.fetch() else { return .nop }
            return .ld_hl_sp_n(source: addr)
        }
        
        if address == 0xF9 {
            return .ld_sp_hl
        }
        
        if address == 0x08 {
            guard let addr = self.cpu.fetchHalfWord() else { return .nop }
            return .ld_nn_sp(address: addr)
        }
        
        switch address {
            case 0x01:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .loadImmediate16(dest: .bc, value: addr)
                
            case 0x11:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .loadImmediate16(dest: .de, value: addr)
                    
            case 0x21:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .loadImmediate16(dest: .hl, value: addr)
                
            case 0x31:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .loadImmediate16(dest: .sp, value: addr)
                
            default:
            return nil
        }
    }
    
    private func controlArithmeticImm(_ address: UInt8) -> Instruction? {
        
        switch address {
            case 0xC6:
                guard let n = self.cpu.fetch() else { return .nop }
                return .add_n(n: n)
                
            case 0xCE:
                guard let n = self.cpu.fetch() else { return .nop }
                return .adc_n(n: n)
                
            case 0xD6:
                guard let n = self.cpu.fetch() else { return .nop }
                return .sub_n(n: n)
                
            case 0xDE:
                guard let n = self.cpu.fetch() else { return .nop }
                return .sbc_n(n: n)
                
            case 0xE6:
                guard let n = self.cpu.fetch() else { return .nop }
                return .and_n(n: n)
                
            case 0xEE:
                guard let n = self.cpu.fetch() else { return .nop }
                return .xor_n(n: n)
                
            case 0xF6:
                guard let n = self.cpu.fetch() else { return .nop }
                return .or_n(n: n)
                
            case 0xFE:
                guard let n = self.cpu.fetch() else { return .nop }
                return .cp_n(n: n)
                
            default:
                return nil
        }
    }
    
    private func controlArithmetic16(_ address: UInt8) -> Instruction? {
        if address == 0xE8 {
            guard let istr = self.cpu.fetch() else { return .nop }
            return .add_sp_n(source: istr)
        }
        
        let source: Target16
        switch address {
        case 0x09: source = .bc
        case 0x19: source = .de
        case 0x29: source = .hl
        case 0x39: source = .sp
        default  : return nil
        }
        return .add_hl(source: source)
        
    }
    
    private func controlJump(_ address: UInt8) -> Instruction? {
        if address == 0xE9 { return .jp_hl }
        
        let jrTemp: Instruction?
        switch address {
            case 0x18:
                guard let byte = self.cpu.fetch() else { jrTemp = .nop; break }
                jrTemp = .jr(condition: nil, offset: Int8(bitPattern: byte))
                
            case 0x20:
                guard let byte = self.cpu.fetch() else { jrTemp = .nop; break }
                jrTemp = .jr(condition: .notZero, offset: Int8(bitPattern: byte))
                
            case 0x28:
                guard let byte = self.cpu.fetch() else { jrTemp = .nop; break }
                jrTemp = .jr(condition: .zero, offset: Int8(bitPattern: byte))
                
            case 0x30:
                guard let byte = self.cpu.fetch() else { jrTemp = .nop; break }
                jrTemp = .jr(condition: .notCarry, offset: Int8(bitPattern: byte))
                
            case 0x38:
                guard let byte = self.cpu.fetch() else { jrTemp = .nop; break }
                jrTemp = .jr(condition: .carry,    offset: Int8(bitPattern: byte))
                
            default: jrTemp = nil
        }
        
        if jrTemp != nil { return jrTemp }
        
        switch address {
            case 0xC3:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .jp(condition: nil, instruction: addr)
            
            case 0xC2:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .jp(condition: .notZero, instruction: addr)
            
            case 0xCA:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .jp(condition: .zero, instruction: addr)
                
            case 0xD2:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .jp(condition: .notCarry, instruction: addr)
                
            case 0xDA:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .jp(condition: .carry, instruction: addr)
                
            default: return nil
        }
        
    }
    
    private func controlCallRet(_ address: UInt8) -> Instruction? {
        
        let tempRet: Instruction? = switch address {
        case 0xC0: .ret(condition: .notZero)
        case 0xC8: .ret(condition: .zero)
        case 0xC9: .ret(condition: nil)
        case 0xD0: .ret(condition: .notCarry)
        case 0xD8: .ret(condition: .carry)
        default  : nil
        }
        if tempRet != nil { return tempRet }
        
        
        let tempAddr: UInt16? = switch address {
        case 0xC7: 0x0000
        case 0xCF: 0x0008
        case 0xD7: 0x0010
        case 0xDF: 0x0018
        case 0xE7: 0x0020
        case 0xEF: 0x0028
        case 0xF7: 0x0030
        case 0xFF: 0x0038
        default  : nil
        }
        if tempAddr != nil { return .rst(address: tempAddr!) }
                
        switch address {
            case 0xC4:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .call(condition: .notZero,  address: addr)
            
            case 0xCC:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .call(condition: .zero,     address: addr)
            
            case 0xCD:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .call(condition: nil,       address: addr)
            
            case 0xD4:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .call(condition: .notCarry, address: addr)
            
            case 0xDC:
                guard let addr = self.cpu.fetchHalfWord() else { return .nop }
                return .call(condition: .carry,    address: addr)
            
            default: return nil
        }
    }
    
    private func controlStack(_ address: UInt8) -> Instruction? {
        var target: Target16? = switch address {
            case 0xC5: .bc
            case 0xD5: .de
            case 0xE5: .hl
            case 0xF5: .af
            default:   nil
        }
        if target != nil { return .push(target: target!) }
        
        target = switch address {
            case 0xC1: .bc
            case 0xD1: .de
            case 0xE1: .hl
            case 0xF1: .af
            default:   nil
        }
        
        if target != nil { return .pop(target: target!) }
        
        return nil
    }
    
    // MARK: - Handled CB
    private func decodeCB() -> Instruction {
        guard let opcode = self.cpu.fetch() else { return .nop}
        
        let firstBlock  = (opcode >> 6) & 0b11
        let secondBlock = (opcode >> 3) & 0b111
        let thirdBlock  = opcode & 0b111
        
        let target = self.cpu.decodeRegister(thirdBlock)
        
        switch firstBlock {
        case 0:
            let type: RotationType = switch secondBlock {
            case 0: .rlc
            case 1: .rrc
            case 2: .rl
            case 3: .rr
            case 4: .sla
            case 5: .sra
            case 6: .swap
            case 7: .srl
            default: .rlc
            }
            return .rotate(type: type, target: target)
            
        case 1: // BIT
            return .bit(index: secondBlock, target: target)
            
        case 2: // RES
            return .res(index: secondBlock, target: target)
            
        case 3: // SET
            return .set(index: secondBlock, target: target)
            
        default:
            return .nop
        }
    }
}
