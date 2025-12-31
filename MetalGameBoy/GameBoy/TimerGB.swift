//
//  Timer.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 31/12/25.
//

class TimerGB {
    var div: UInt8 = 0
    
    private var divCounter: Int = 0
    
    func step(_ cycles: Int) {
        self.divCounter += cycles
        
        if self.divCounter >= 256 {
            self.divCounter -= 256
            self.div &+= 1
        }
    }
    
    func resetDiv() {
        self.div = 0
        self.divCounter = 0
    }
}
