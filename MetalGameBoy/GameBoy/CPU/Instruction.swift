//
//  Instruction.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 30/12/25.
//

enum Instruction {
    // MARK: - Control Flow & SystemBusy CPU operation
    case nop  // 0x00: No operation
    case stop // 0x10: Stop CPU and LCD (low power mode)
    case halt // 0x76: Halt CPU until interrupt
    
    
    
    // MARK: - Interrupt Instructions
    case ei   // 0xFB: Enable interrupt (ime = true)
    case di   // 0xF3: Disable interrupt (ime = false)
    case reti // 0xD9: Return from Interrupt (RET + EI)
    
    
    
    // MARK: - 8-bit Load Instructions
    // Register to Register / Memory
    case load(to: Target, from: Target) // 0x40-0x7F: LD r, r' (include (HL)
    case loadImmediate(dest: Target, value: UInt8) // 0x06, 0x0E, etc: LD r, n
    
    
    // Special Accumulator <-> Memory Loads
    case ld_a_rr(source: Target16) // 0x0A, 0x1A: LD A, (BC/DE)
    case ld_rr_a(target: Target16) // 0x02, 0x12: LD (BC/DE), A
    
    case ld_a_nn(addr: UInt16) // 0xFA: LD A, (nn)
    case ld_nn_a(addr: UInt16) // 0xEA: LD (nn), A
    
    
    // High RAM (0xFF00+n) loads - I/O optimized
    case ldh_a_n(n: UInt8) // 0xF0: LDH A, (0xFF00+n)
    case ldh_n_a(n: UInt8) // 0xE0: LDH (0xFF00+n), A
    
    case ldh_a_c // 0xF2: LD A, (0xFF00+C)
    case ldh_c_a // 0xE2: LD (0xFF00+C), A
    
    
    // HL Auto-increment/decrement loads
    case ldi_a_hl // 0x2A: LD A, (HL+) [HL last ++]
    case ldi_hl_a // 0x22: LD (HL+), A [HL last ++]
    
    case ldd_a_hl // 0x3A: LD A, (HL-) [HL last --]
    case ldd_hl_a // 0x32: LD (HL-), A  [HL last --]
    
    
    
    // MARK: - 16-bit Load Instructions
    case loadImmediate16(
        dest : Target16,
        value: UInt16
    ) // 0x01, 0x11, 0x21, 0x31: LD rr, nn
    
    case ld_sp_hl                  // 0xF9: LD SP, HL
    case ld_hl_sp_n(source: UInt8) // 0xF8: LD HL, SP+n (signed offset)
    case ld_nn_sp(address: UInt16) // 0x08: LD (nn), SP
    
    
    
    // MARK: - 8-bit Arithmetic (Register/Memory operands)
    case add(source: Target) // 0x80-0x87: ADD A, r
    case adc(source: Target) // 0x88-0x8F: ADC A, r (Add with Carry)
    
    case sub(source: Target) // 0x90-0x97: SUB A, r
    case sbc(source: Target) // 0x98-0x9F: SBC A, r (Subtract with Carry)
    
    case and(source: Target) // 0xA0-0xA7: AND A, r
    case xor(source: Target) // 0xA8-0xAF: XOR A, r
    case or(source: Target)  // 0xB0-0xB7: OR A, r
    case cp(source: Target)  // 0xB8-0xBF: CP A, r (Compare, only flag)
    
    
    
    // MARK: - 8-bit Arithmetic (Immediate operands)
    case add_n(n: UInt8) // 0xC6: ADD A, n
    case adc_n(n: UInt8) // 0xCE: ADC A, n
    case sub_n(n: UInt8) // 0xD6: SUB A, n
    case sbc_n(n: UInt8) // 0xDE: SBC A, n
    case and_n(n: UInt8) // 0xE6: AND A, n
    case xor_n(n: UInt8) // 0xEE: XOR A, n
    case or_n(n: UInt8)  // 0xF6: OR A, n
    case cp_n(n: UInt8)  // 0xFE: CP A, n
    
    
    
    // MARK: - 8-bit Inc/Dec
    case inc(target: Target) // 0x04, 0x0C, etc: INC r
    case dec(target: Target) // 0x05, 0x0D, etc: DEC r
    
    
    
    // MARK: - 16-bit Arithmetic
    case add_hl(source: Target16) // 0x09, 0x19, 0x29, 0x39: ADD HL, rr
    case add_sp_n(source: UInt8)  // 0xE8: ADD SP, n (signed offset)
    
    case inc16(target: Target16) // 0x03, 0x13, 0x23, 0x33: INC rr
    case dec16(target: Target16) // 0x0B, 0x1B, 0x2B, 0x3B: DEC rr
    
    
    
    // MARK: - Jump Instructions
    case jp(
        condition  : JumpCondition?,
        instruction: UInt16
    ) // 0xC3, 0xC2, etc: JP [cc,] nn
    
    case jp_hl // 0xE9: JP HL (Jump to address content in HL)
    
    case jr(
        condition: JumpCondition?,
        offset   : Int8
    ) // 0x18, 0x20, etc: JR [cc,] e
    
    
    
    // MARK: - Call/Return Instructions
    case call(
        condition: JumpCondition?,
        address  : UInt16
    ) // 0xCD, 0xC4, etc: CALL [cc,] nn
    
    case ret(condition: JumpCondition?) // 0xC9, 0xC0, etc: RET [cc]
    case rst(address: UInt16)           // 0xC7, 0xCF, etc: RST n (CALL fast)
    
    
    
    // MARK: - Stack Operations
    case push(target: Target16) // 0xC5, 0xD5, 0xE5, 0xF5: PUSH rr
    case pop(target: Target16)  // 0xC1, 0xD1, 0xE1, 0xF1: POP rr
    
    
    
    // MARK: - Rotate & Shift (Fast A-register variants)
    case rotateA(type: RotationType) // 0x07, 0x0F, 0x17, 0x1F: RLCA, RRCA, RLA, RRA
        
    
    
    // MARK: - Miscellaneous A-register Operations
    case daa // 0x27: Decimal Adjust A (per BCD)
    case cpl // 0x2F: Complement A (bitwise NOT)
    case scf // 0x37: Set Carry Flag
    case ccf // 0x3F: Complement Carry Flag
        
    
    // MARK: - CB-Prefixed Instructions (0xCB xx)
    // Bit Operations
    case bit(index: UInt8, target: Target) // 0xCB 0x40-0x7F: BIT b, r
    case set(index: UInt8, target: Target) // 0xCB 0xC0-0xFF: SET b, r
    case res(index: UInt8, target: Target) // 0xCB 0x80-0xBF: RES b, r
        
    // Rotate & Shift (General)
    case rotate(
        type  : RotationType,
        target: Target
    ) // 0xCB 0x00-0x3F: RLC, RRC, RL, RR, SLA, SRA, SWAP, SRL
}

enum RotationType {
    case rlc, rrc
    case rl, rr
    case sla, sra
    case swap, srl
}
