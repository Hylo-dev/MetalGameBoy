//
//  ALU.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 31/12/25.
//

struct ALU {
    unowned let cpu: CPU
    
    init(cpu: CPU) {
        self.cpu = cpu
    }
    
    func execute(_ instr: Instruction) -> Int {
        switch instr {
        case .nop, .stop:
            return 4
            
        case .halt:
            self.cpu.isHalted = true
            return 4
            
        case .load(to: let dest, from: let src):
            self.cpu.setVal(self.cpu.getVal(src), in: dest)
            return (dest == .hlPointer || src == .hlPointer) ? 8 : 4
            
        case .add(source: let source):
            aluAdd(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .adc(source: let source):
            aluAdc(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .sub(source: let source):
            aluSub(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .sbc(source: let source):
            aluSbc(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .and(source: let source):
            aluAnd(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .xor(source: let source):
            aluXor(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .or(source: let source):
            aluOr(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .cp(source: let source):
            aluCp(self.cpu.getVal(source))
            return source == .hlPointer ? 8 : 4
            
        case .jp(condition: let cond, instruction: let address):
            
            if cond == nil { self.cpu.pc = address; return 16 }
            
            if checkJumpCondition(cond!) {
                self.cpu.pc = address
                return 16
            }
            
            return 12
            
        case .jr(condition: let condition, offset: let offset):
            if condition == nil {
                let newPC = Int(self.cpu.pc) &+ Int(offset)
                self.cpu.pc = UInt16(newPC & 0xFFFF)
                return 12
            }
            
            if checkJumpCondition(condition!) {
                let newPC = Int(self.cpu.pc) + Int(offset)
                self.cpu.pc = UInt16(newPC & 0xFFFF)
                return 12
            }
            
            return 8
            
        case .call(condition: let cond, address: let addr):
            if cond == nil {
                pushWord(self.cpu.pc)
                self.cpu.pc = addr
                return 24
            }
            
            if checkJumpCondition(cond!) {
                pushWord(self.cpu.pc)
                self.cpu.pc = addr
                return 24
            }
            
            return 12
            

        case .ret(condition: let cond):
            if cond == nil {
                let retAddr = popWord()
                self.cpu.pc = retAddr
                return 16
            }
            
            if checkJumpCondition(cond!) {
                let retAddr = popWord()
                self.cpu.pc = retAddr
                return 20
            }

            return 8
            
        case .bit(index: let index, target: let target):
            cbBit(index: index, target: target)
            return target == .hlPointer ? 12 : 8
            
        case .set(index: let index, target: let target):
            cbSet(index: index, target: target)
            return target == .hlPointer ? 16 : 8
            
        case .res(index: let index, target: let target):
            cbRes(index: index, target: target)
            return target == .hlPointer ? 16 : 8
            
        case .rotate(type: let type, target: let target):
            cbRotate(type: type, target: target)
            return target == .hlPointer ? 16 : 8
            
        case .ei:
            self.cpu.ime = true
            return 4
            
        case .di:
            self.cpu.ime = false
            return 4
            
            
        case .loadImmediate(dest: let target, value: let val):
            self.cpu.setVal(val, in: target)
            return target == .hlPointer ? 12 : 8

        case .inc(target: let target):
            // INC modifica i flag Zero, HalfCarry, Subtraction (non Carry!)
            let oldVal = self.cpu.getVal(target)
            let newVal = oldVal &+ 1
            self.cpu.setVal(newVal, in: target)
                
            self.cpu.setFlag(value: .zero, newVal == 0)
            self.cpu.setFlag(value: .subtraction, false)
            self.cpu.setFlag(value: .halfCarry, (oldVal & 0xF) == 0xF) // Carry dal bit 3
            return target == .hlPointer ? 12 : 4

        case .dec(target: let target):
            // DEC modifica Zero, HalfCarry, Subtraction
            let oldVal = self.cpu.getVal(target)
            let newVal = oldVal &- 1
            self.cpu.setVal(newVal, in: target)
                
            self.cpu.setFlag(value: .zero, newVal == 0)
            self.cpu.setFlag(value: .subtraction, true)
            self.cpu.setFlag(value: .halfCarry, (oldVal & 0xF) == 0) // Borrow dal bit 4
            return target == .hlPointer ? 12 : 4
            

        case .loadImmediate16(dest: let dest, value: let value):
            switch dest {
                case .bc: self.cpu.bc = value
                case .de: self.cpu.de = value
                case .hl: self.cpu.hl = value
                case .sp: self.cpu.sp = value
                case .af: self.cpu.af = value
            }
            return 12
            
        case .ldh_n_a(n: let n):
            self.cpu.mmu.writeByte(self.cpu.a, in: 0xFF00 + UInt16(n))
            return 12
                
        case .ldh_a_n(n: let n):
            self.cpu.a = self.cpu.mmu.readByte(0xFF00 + UInt16(n)) ?? 0
            return 12
                
        case .ldh_c_a:
            self.cpu.mmu.writeByte(self.cpu.a, in: 0xFF00 + UInt16(self.cpu.c))
            return 8
                    
        case .ldh_a_c:
            self.cpu.a = self.cpu.mmu.readByte(0xFF00 + UInt16(self.cpu.c)) ?? 0
            return 8
                    
        case .ld_nn_a(addr: let addr):
            self.cpu.mmu.writeByte(self.cpu.a, in: addr)
            return 16
                    
        case .ld_a_nn(addr: let addr):
            self.cpu.a = self.cpu.mmu.readByte(addr) ?? 0
            return 16
            
            
        case .ldi_hl_a: // 0x22: Scrive A in (HL), poi HL++
            self.cpu.mmu.writeByte(self.cpu.a, in: self.cpu.hl)
            self.cpu.hl &+= 1
            return 8

        case .ldd_hl_a: // 0x32: Scrive A in (HL), poi HL--
            self.cpu.mmu.writeByte(self.cpu.a, in: self.cpu.hl)
            self.cpu.hl &-= 1
            return 8

        case .ldi_a_hl: // 0x2A: Legge (HL) in A, poi HL++
            self.cpu.a = self.cpu.mmu.readByte(self.cpu.hl) ?? 0
            self.cpu.hl &+= 1
            return 8
            
        case .ldd_a_hl: // 0x3A: Legge (HL) in A, poi HL--
            self.cpu.a = self.cpu.mmu.readByte(self.cpu.hl) ?? 0
            self.cpu.hl &-= 1
            return 8
            
            
        case .ld_rr_a(target: let target):
            // Scrive A nell'indirizzo puntato da BC o DE
            let addr = (target == .bc) ? self.cpu.bc : self.cpu.de
            self.cpu.mmu.writeByte(self.cpu.a, in: addr)
            return 8
                    
        case .ld_a_rr(source: let source):
            // Legge in A dall'indirizzo puntato da BC o DE
            let addr = (source == .bc) ? self.cpu.bc : self.cpu.de
            self.cpu.a = self.cpu.mmu.readByte(addr) ?? 0
            return 8
                    
        // ALU Immediate
        case .add_n(n: let n): aluAdd(n); return 8
        case .adc_n(n: let n): aluAdc(n); return 8
        case .sub_n(n: let n): aluSub(n); return 8
        case .sbc_n(n: let n): aluSbc(n); return 8
        case .and_n(n: let n): aluAnd(n); return 8
        case .xor_n(n: let n): aluXor(n); return 8
        case .or_n(n: let n):  aluOr(n);  return 8
        case .cp_n(n: let n):  aluCp(n);  return 8
            
        case .push(target: let target):
            // Legge il valore a 16 bit dal registro target
            let val: UInt16 = switch target {
                case .bc: self.cpu.bc
                case .de: self.cpu.de
                case .hl: self.cpu.hl
                case .af: self.cpu.af
                default: 0
            }
            pushWord(val)
            return 16

        case .pop(target: let target):
            let val = popWord()
            // Scrive il valore nel registro target
            switch target {
                case .bc: self.cpu.bc = val
                case .de: self.cpu.de = val
                case .hl: self.cpu.hl = val
                case .af: self.cpu.af = val // Nota: la proprietà 'af' gestisce già i bit bassi di F
                default: break
            }
            return 12

        case .reti:
            // Ritorna dall'interrupt E riabilita gli interrupt master
            let retAddr = popWord()
            self.cpu.pc = retAddr
            self.cpu.ime = true // Riabilita Interrupt Master Enable
            return 16
        
        case .inc16(target: let target):
            // INC 16 bit NON aggiorna i flag
            switch target {
                case .bc: self.cpu.bc = self.cpu.bc &+ 1
                case .de: self.cpu.de = self.cpu.de &+ 1
                case .hl: self.cpu.hl = self.cpu.hl &+ 1
                case .sp: self.cpu.sp = self.cpu.sp &+ 1
                default: break
            }
            return 8
                    
        case .dec16(target: let target):
            // DEC 16 bit NON aggiorna i flag
            switch target {
                case .bc: self.cpu.bc = self.cpu.bc &- 1
                case .de: self.cpu.de = self.cpu.de &- 1
                case .hl: self.cpu.hl = self.cpu.hl &- 1
                case .sp: self.cpu.sp = self.cpu.sp &- 1
                default: break
            }
            return 8
            
        case .rotateA(type: let type):
            // Esegue la rotazione su A
            cbRotate(type: type, target: .a)
            // FIX: Le istruzioni 0x07, 0x0F, 0x17, 0x1F mettono SEMPRE Zero Flag a 0
            self.cpu.setFlag(value: .zero, false)
            return 4 // Sono più veloci delle versioni CB (4 cicli vs 8)
                                
            // In CPU.swift -> execute

        case .cpl:
            // Inverte tutti i bit di A
            self.cpu.a = ~self.cpu.a
            self.cpu.setFlag(value: .subtraction, true)
            self.cpu.setFlag(value: .halfCarry, true)
            return 4

        case .scf:
            // Setta Carry
            self.cpu.setFlag(value: .subtraction, false)
            self.cpu.setFlag(value: .halfCarry, false)
            self.cpu.setFlag(value: .carry, true)
            return 4

        case .ccf:
            // Inverte Carry
            self.cpu.setFlag(value: .subtraction, false)
            self.cpu.setFlag(value: .halfCarry, false)
            self.cpu.setFlag(value: .carry, !self.cpu.getFlagStatus(value: .carry))
            return 4

        case .daa:
            var adjust: UInt8 = 0
            
            if self.cpu.getFlagStatus(value: .halfCarry) || (!self.cpu.getFlagStatus(value: .subtraction) && (self.cpu.a & 0x0F) > 0x09) {
                adjust |= 0x06
            }
            
            if self.cpu.getFlagStatus(value: .carry) || (!self.cpu.getFlagStatus(value: .subtraction) && self.cpu.a > 0x99) {
                adjust |= 0x60
                self.cpu.setFlag(value: .carry, true)
            }
            
            if self.cpu.getFlagStatus(value: .subtraction) {
                self.cpu.a = self.cpu.a &- adjust
            } else {
                self.cpu.a = self.cpu.a &+ adjust
            }
            
            self.cpu.setFlag(value: .zero, self.cpu.a == 0)
            self.cpu.setFlag(value: .halfCarry, false)
            return 4
            
        case .jp_hl: // 0xE9
            self.cpu.pc = self.cpu.hl // Salta direttamente all'indirizzo in HL
            return 4
            
        case .rst(address: let addr):
            pushWord(self.cpu.pc)
            self.cpu.pc = addr
            return 16
            
        case .add_hl(source: let source):
            let value: UInt16 = switch source {
                case .bc: self.cpu.bc
                case .de: self.cpu.de
                case .hl: self.cpu.hl
                case .sp: self.cpu.sp
                case .af: self.cpu.af
            }
            
            let result = UInt32(self.cpu.hl) + UInt32(value)
            
            self.cpu.setFlag(value: .subtraction, false)
            self.cpu.setFlag(value: .halfCarry, ((self.cpu.hl & 0x0FFF) + (value & 0x0FFF)) > 0x0FFF)
            self.cpu.setFlag(value: .carry, result > 0xFFFF)
            
            self.cpu.hl = UInt16(result & 0xFFFF)
            return 8
            
            
        case .ld_nn_sp(address: let addr):
            let low = UInt8(self.cpu.sp & 0xFF)
            let high = UInt8((self.cpu.sp >> 8) & 0xFF)
            self.cpu.mmu.writeByte(low, in: addr)
            self.cpu.mmu.writeByte(high, in: addr + 1)
            return 20
            
        case .add_sp_n(source: let n):
            let offset = Int8(bitPattern: n)
            let result = Int(self.cpu.sp) + Int(offset)
            
            self.cpu.setFlag(value: .zero, false)
            self.cpu.setFlag(value: .subtraction, false)
            
            // Half carry e carry si calcolano sui byte bassi
            if offset >= 0 {
                self.cpu.setFlag(value: .halfCarry, ((self.cpu.sp & 0x0F) + (UInt16(n) & 0x0F)) > 0x0F)
                self.cpu.setFlag(value: .carry, ((self.cpu.sp & 0xFF) + UInt16(n)) > 0xFF)
            } else {
                self.cpu.setFlag(value: .halfCarry, (result & 0x0F) <= (Int(self.cpu.sp) & 0x0F))
                self.cpu.setFlag(value: .carry, (result & 0xFF) <= (Int(self.cpu.sp) & 0xFF))
            }
            
            self.cpu.sp = UInt16(result & 0xFFFF)
            return 16
            
        case .ld_hl_sp_n(source: let n):
            let offset = Int8(bitPattern: n)
            let result = Int(self.cpu.sp) + Int(offset)
            
            self.cpu.setFlag(value: .zero, false)
            self.cpu.setFlag(value: .subtraction, false)
            
            if offset >= 0 {
                self.cpu.setFlag(value: .halfCarry, ((self.cpu.sp & 0x0F) + (UInt16(n) & 0x0F)) > 0x0F)
                self.cpu.setFlag(value: .carry, ((self.cpu.sp & 0xFF) + UInt16(n)) > 0xFF)
            } else {
                self.cpu.setFlag(value: .halfCarry, (result & 0x0F) <= (Int(self.cpu.sp) & 0x0F))
                self.cpu.setFlag(value: .carry, (result & 0xFF) <= (Int(self.cpu.sp) & 0xFF))
            }
            
            self.cpu.hl = UInt16(result & 0xFFFF)
            return 12
            
        case .ld_sp_hl:
            self.cpu.sp = self.cpu.hl
            return 8
            
        }
                
    }
    
    // MARK: - Stack
    private func pushWord(_ value: UInt16) {
        let high = UInt8((value >> 8) & 0xFF)
        let low  = UInt8(value & 0xFF)
        
        self.cpu.sp -= 1
        self.cpu.mmu.writeByte(high, in: self.cpu.sp)
        
        self.cpu.sp -= 1
        self.cpu.mmu.writeByte(low, in: self.cpu.sp)
    }
    
    private func popWord() -> UInt16{
        let low = self.cpu.mmu.readByte(self.cpu.sp)
        self.cpu.sp += 1
        
        let high = self.cpu.mmu.readByte(self.cpu.sp)
        self.cpu.sp += 1
        
        return (UInt16(high!) << 8) | UInt16(low!)
    }
    
    // MARK: - Jump
    private func checkJumpCondition(_ cond: JumpCondition) -> Bool {
        return switch cond {
        case .notZero:
            !self.cpu.getFlagStatus(value: .zero)
        
        case .zero:
            self.cpu.getFlagStatus(value: .zero)
            
        case .notCarry:
            !self.cpu.getFlagStatus(value: .carry)
            
        case .carry:
            self.cpu.getFlagStatus(value: .carry)
        }
    }
    
    // MARK: - Arithmetic Handle
    private func aluAdd(_ value: UInt8) {
        // Management F register
        let result = UInt16(self.cpu.a) + UInt16(value)
        
        // 1 0 1 0  0 0 0 0
        // 1 1 1 1  1 1 1 1
        // 1 0 1 0  0 0 0 0
        let zero      = (result & 0xFF) == 0
        let carry     = result > 255 // Overflow
        let halfCarry = (self.cpu.a & 0xF) + (value & 0xF) > 0xF
        
        self.cpu.a = UInt8(result & 0xFF)
        
        self.cpu.setFlag(value: .zero, zero)
        self.cpu.setFlag(value: .carry, carry)
        self.cpu.setFlag(value: .halfCarry, halfCarry)
        self.cpu.setFlag(value: .subtraction, false)
    }
    
    private func aluAdc(_ value: UInt8) {
        // Management F register
        
        let currentCarry: UInt16 = self.cpu.getFlagStatus(value: .carry) ? 1 : 0
        
        let result = UInt16(self.cpu.a) + UInt16(value) + currentCarry
        
        // 1 0 1 0  0 0 0 0
        // 1 1 1 1  1 1 1 1
        // 1 0 1 0  0 0 0 0
        let zero      = (result & 0xFF) == 0
        let carry     = result > 255 // Overflow
        let halfCarry = (self.cpu.a & 0xF) + (value & 0xF) + UInt8(currentCarry) > 0xF
        
        self.cpu.a = UInt8(result & 0xFF)
        
        self.cpu.setFlag(value: .zero, zero)
        self.cpu.setFlag(value: .carry, carry)
        self.cpu.setFlag(value: .halfCarry, halfCarry)
        self.cpu.setFlag(value: .subtraction, false)
    }
    
    private func aluSub(_ value: UInt8) {
        let result = Int(self.cpu.a) - Int(value)
        
        // 1 0 1 0  0 0 0 0
        // 1 1 1 1  1 1 1 1
        // 1 0 1 0  0 0 0 0
        let zero      = (result & 0xFF) == 0
        let carry     = result < 0 // Overflow
        let halfCarry = (Int(self.cpu.a) & 0xF) - (Int(value) & 0xF) < 0
        
        self.cpu.a = UInt8(result & 0xFF)
        
        self.cpu.setFlag(value: .zero, zero)
        self.cpu.setFlag(value: .carry, carry)
        self.cpu.setFlag(value: .halfCarry, halfCarry)
        self.cpu.setFlag(value: .subtraction, true)
    }
    
    private func aluSbc(_ value: UInt8) {
        // Management F register
        let currentCarry: Int = self.cpu.getFlagStatus(value: .carry) ? 1 : 0
        
        let result = Int(self.cpu.a) - Int(value) - currentCarry
        
        // 1 0 1 0  0 0 0 0
        // 1 1 1 1  1 1 1 1
        // 1 0 1 0  0 0 0 0
        let zero      = (result & 0xFF) == 0
        let carry     = result < 0 // Overflow
        let halfCarry = (Int(self.cpu.a) & 0xF) - (Int(value) & 0xF) - currentCarry < 0
        
        self.cpu.a = UInt8(result & 0xFF)
        
        self.cpu.setFlag(value: .zero, zero)
        self.cpu.setFlag(value: .carry, carry)
        self.cpu.setFlag(value: .halfCarry, halfCarry)
        self.cpu.setFlag(value: .subtraction, true)
    }
    
    private func aluAnd(_ value: UInt8) {
        self.cpu.a &= value
        
        self.cpu.setFlag(value: .zero, self.cpu.a == 0)
        self.cpu.setFlag(value: .carry, false)
        self.cpu.setFlag(value: .halfCarry, true)
        self.cpu.setFlag(value: .subtraction, false)
    }
    
    private func aluXor(_ value: UInt8) {
        self.cpu.a ^= value
        
        self.cpu.setFlag(value: .zero, self.cpu.a == 0)
        self.cpu.setFlag(value: .carry, false)
        self.cpu.setFlag(value: .halfCarry, false)
        self.cpu.setFlag(value: .subtraction, false)
    }
    
    private func aluOr(_ value: UInt8) {
        self.cpu.a |= value
        
        self.cpu.setFlag(value: .zero, self.cpu.a == 0)
        self.cpu.setFlag(value: .carry, false)
        self.cpu.setFlag(value: .halfCarry, false)
        self.cpu.setFlag(value: .subtraction, false)
    }
    
    private func aluCp(_ value: UInt8) {
        let result = Int(self.cpu.a) - Int(value)
        
        // 1 0 1 0  0 0 0 0
        // 1 1 1 1  1 1 1 1
        // 1 0 1 0  0 0 0 0
        let zero      = (result & 0xFF) == 0
        let carry     = result < 0 // Overflow
        let halfCarry = (Int(self.cpu.a) & 0xF) - (Int(value) & 0xF) < 0
                
        self.cpu.setFlag(value: .zero, zero)
        self.cpu.setFlag(value: .carry, carry)
        self.cpu.setFlag(value: .halfCarry, halfCarry)
        self.cpu.setFlag(value: .subtraction, true)
    }
    
    // MARK: - CB Handler
    private func cbBit(
        index : UInt8,
        target: Target
    ) {
        let mask: UInt8 = 1 << index
        
        let value = self.cpu.getVal(target)
                
        self.cpu.setFlag(value: .zero, (value & mask) == 0)
        self.cpu.setFlag(value: .subtraction, false)
        self.cpu.setFlag(value: .halfCarry, true)
    }
    
    private func cbSet(
        index : UInt8,
        target: Target
    ) {
        let mask: UInt8 = 1 << index
        
        let value = self.cpu.getVal(target)
                
        self.cpu.setVal(value | mask, in: target)
    }
    
    private func cbRes(
        index : UInt8,
        target: Target
    ) {
        let mask: UInt8 = 1 << index
        
        let value = self.cpu.getVal(target)
                
        self.cpu.setVal(value & ~mask, in: target)
    }
    
    private func cbRotate(
        type: RotationType,
        target: Target
    ) {
        let value = self.cpu.getVal(target)
                
        let carry: Bool
        let result: UInt8
        
        switch type {
        case .rlc:
            
            // 1 0 1 1 0 0 0 0
            // 0 0 0 0 0 0 0 1
            
            carry = (value & 0x80) != 0
            result = (value << 1) | (carry ? 1 : 0)
            
        case .rrc:
            carry = (value & 0x01) != 0
            result = (value >> 1) | (carry ? 0x80 : 0)
            
        case .rl:
            carry = (value & 0x80) != 0
            let oldCarry = self.cpu.getFlagStatus(value: .carry) ? 1 : 0
            result = (value << 1) | UInt8(oldCarry)
            
        case .rr:
            carry = (value & 0x01) != 0
            let oldCarry = self.cpu.getFlagStatus(value: .carry) ? 1 : 0
            result = (value >> 1) | UInt8(oldCarry << 7)
            
        case .sla:
            carry = (value & 0x80) != 0
            result = value << 1
            
        case .sra:
            carry = (value & 0x01) != 0
            let bit7 = value & 0x80
            result = (value >> 1) | bit7
            
        case .srl:
            carry = (value & 0x01) != 0
            result = value >> 1
            
        case .swap:
            carry = false
            result = ((value & 0x0F) << 4) | ((value & 0xF0) >> 4)
        }
        
        self.cpu.setVal(result, in: target)
                
        self.cpu.setFlag(value: .zero, result == 0)
        self.cpu.setFlag(value: .subtraction, false)
        self.cpu.setFlag(value: .halfCarry, false)
        self.cpu.setFlag(value: .carry, carry)
    }
}
