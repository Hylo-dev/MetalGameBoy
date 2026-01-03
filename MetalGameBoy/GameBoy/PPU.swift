import Foundation

final class PPU {
    
    unowned let mmu: MMU
    
    let oamSize = 0xA0
    var oam: UnsafeMutablePointer<UInt8>
    
    let vramSize = 0x2000
    var vram: UnsafeMutablePointer<UInt8>
    
    private let bgPriorityBufferSize = 160
    private var bgPriorityBuffer: UnsafeMutablePointer<UInt8>
    
    private var counter: Int64 = 0
    private(set) var lineY: UInt8 = 0
    
    // Flag PPU mode (HBlank, VBlank, OAM Search, Pixel Transfer)
    // Used for compatibility
    private var mode: UInt8 = 2
    
    // Video Buffer: 160x144 pixel
    static let screenWidth = 160
    static let screenHeight = 144
    
    let bufferSize = screenWidth * screenHeight * 4
    var frameBuffer: UnsafeMutablePointer<UInt8>
    
    init (mmu: MMU) {
        self.mmu = mmu
        
        self.frameBuffer = UnsafeMutablePointer.allocate(capacity: bufferSize)
        self.frameBuffer.initialize(repeating: 255, count: bufferSize)
        
        self.oam = UnsafeMutablePointer.allocate(capacity: oamSize)
        self.oam.initialize(repeating: 0, count: oamSize)
        
        self.vram = UnsafeMutablePointer.allocate(capacity: vramSize)
        self.vram.initialize(repeating: 0, count: vramSize)
        
        self.bgPriorityBuffer = UnsafeMutablePointer.allocate(
            capacity: bgPriorityBufferSize
        )
        self.bgPriorityBuffer.initialize(
            repeating: 0,
            count    : bgPriorityBufferSize
        )
    }
    
    deinit {
        self.frameBuffer.deallocate()
        self.oam.deallocate()
        self.vram.deallocate()
    }
    
    @inline(__always)
    func readVRAM(_ addr: UInt16) -> UInt8 {
        return vram[Int(addr & 0x1FFF)]
    }
    
    func step(_ cycles: Int) {
        // Control if LCD is on (Bit 7 LCDC 0xFF40)
        let lcdc = self.mmu.readByte(0xFF40) ?? 0
        
        // LCD Off: Reset all
        if (lcdc & 0x80) == 0 {
            self.lineY   = 0
            self.counter = 0
            self.mode    = 0
            return
        }
        
        self.counter += Int64(cycles)
        updateStatRegister()
        
        if self.counter >= 456 {
            self.counter -= 456
            
            // Draw current line
            if self.lineY < 144 { drawScanline() }
            
            self.lineY += 1
            
            // Manage VBlank Interrupt
            if self.lineY == 144, let intFlag = self.mmu.readByte(0xFF0F){
                // Request VBlank Interrupt
                self.mmu.writeByte(intFlag | 0x01, in: 0xFF0F)
            }
            
            // Reset LY reg
            if self.lineY > 153 { self.lineY = 0 }
        }
    }
    
    private func updateStatRegister() {
        var newMode: UInt8 = 0
            
        if self.lineY >= 144 {
            newMode = 1 // VBLANK
            
        } else if self.counter < 80 {
            newMode = 2 // OAM Search
                
        } else if self.counter < 252 {
            newMode = 3 // Pixel Transfer
            
        } else { newMode = 0 } // HBlank
        
        // Manage Interrupt STAT
        var reqInt = false
            
        // Read current value for STAT reg
        var stat = self.mmu.readByte(0xFF41) ?? 0
            
        // Set new mode for PPU draw
        if newMode != self.mode {
                
            // Mode 0 (HBlank) && Bit 3 is 1 exec -> INT
            if newMode == 0 && (stat & 0x08) != 0 { reqInt = true }
                
            // Mode 1 (VBlank) && Bit 4 is 1 exec -> INT
            if newMode == 1 && (stat & 0x10) != 0 { reqInt = true }
                
            // Mode 2 (OAM) && Bit 5 is 1 exec -> INT
            if newMode == 2 && (stat & 0x20) != 0 { reqInt = true }
                
            self.mode = newMode
        }
            
        // Read LYC reg, this register is used
        // for the game when needed "notify me in the X row"
        // LYC = Line Y control
        let lyc = self.mmu.readByte(0xFF45) ?? 0
            
        // Bit 2 in STAT: 1 if LY == LYC, else 0
        if self.lineY == lyc {
            stat |= 0x04 // Set bit 2
            
            // If Bit 6 is active && LY == LYC exec -> INT
            if (stat & 0x40) != 0 { reqInt = true }
            
        } else { stat &= ~0x04 } // Pulisci bit 2
                    
        // Write the bit in mode (0 and 1) in the STAT reg
        // Clean first 2 bit and set this in to new mode
        stat = (stat & 0xFC) | (newMode & 0x03)
        self.mmu.writeByte(stat, in: 0xFF41)
            
        // Launch INT if is needed
        if reqInt, let ifReg = self.mmu.readByte(0xFF0F) {
            // Bit 1 in IF reg is LCD STAT INT
            self.mmu.writeByte(ifReg | 0x02, in: 0xFF0F)
        }
    }
    
    
    @inline(__always)
    private func drawScanline() {
        // Get LCD Control state
        let lcdc = self.mmu.readByte(0xFF40) ?? 0
        
        // If LCD is ON and bit 1 is ON then render bg,
        // else clean Priority Buffer
        if (lcdc & 0x01) != 0 {
            renderBackground(lcdc)
            
        } else {
            for i in 0..<160 {
                bgPriorityBuffer[i] = 0
            }
        }
        
        // LCDC Reg have bit 2 on then render sprites
        if (lcdc & 0x02) != 0 { renderSprites(lcdc) }
    }
    
    private func renderBackground(_ lcdc: UInt8) {
        // Get scroll x reg value
        let scx = self.mmu.readByte(0xFF43) ?? 0
        
        // Get scroll y reg value
        let scy = self.mmu.readByte(0xFF42) ?? 0
        
        // Get palette reg value
        let palette = self.mmu.readByte(0xFF47) ?? 0
            
        // Map is in 0x9800 or 0x9C00 address
        let mapBase: UInt16 = (lcdc & 0x08) != 0 ? 0x9C00 : 0x9800
                        
        // For a get absolute coordinate use
        // LY reg value and add this to scroll y
        let yPos = self.lineY &+ scy
            
        let tileRow = UInt16(yPos / 8)
        let pixelRowInTile = UInt16(yPos % 8)
            
        // Draw 160 pixel
        for x in 0..<160 {
            let xPos = UInt8(x) &+ scx
            let tileCol = UInt16(xPos / 8)
            let pixelColInTile = UInt8(xPos % 8)
             
            // Calc address in the tile map, this have 32 columns for rows
            // (tileRow * 32) get start for the correct row
            // & 0x3FF is used for "wrapping",
            // if the number is outside on the map, draw on start map
            let mapIndex = (tileRow * 32 + tileCol) & 0x3FF
            let tileMapAddress = mapBase + mapIndex
                
            // Get tile ID
            let tileID = readVRAM(tileMapAddress)
                
            var tileDataAddress: UInt16 = 0
            if (lcdc & 0x10) == 0 {
                // Method signed 0x8800 (ID range -128 ... 127)
                // 0x9000 is the center, + (ID * 16 byte each tile)
                let signedID = Int8(bitPattern: tileID)
                tileDataAddress = UInt16(Int(0x9000) + Int(signedID) * 16)
                
            } else {
        
                // Method unsigned, most nonrmal 0x8000 (ID range 0 ... 255)
                tileDataAddress = 0x8000 + UInt16(tileID) * 16
            }
                
            // Each tile row use 2B (L & H) for coding the colors
            let byte1 = readVRAM(tileDataAddress + (pixelRowInTile * 2))
            let byte2 = readVRAM(tileDataAddress + (pixelRowInTile * 2) + 1)
                
            // Get color in the bit
            // Bit 7 is the left pixel, Bit 0 is rigt pixel
            let bitIndex = 7 - Int(pixelColInTile)
            let bitLow  = (byte1 >> bitIndex) & 0x01
            let bitHigh = (byte2 >> bitIndex) & 0x01
                
            // Color ID (0, 1, 2, 3)
            let colorID = (bitHigh << 1) | bitLow
                
            // Save info color for the sprite into buffer
            self.bgPriorityBuffer[x] = colorID
                
            // Set palette
            let realColor = getPaletteColor(colorID: colorID, palette: palette)
                
            // Scriviamo nel FrameBuffer
            putPixel(x: x, color: realColor)
        }
    }
        
    private func renderSprites(_ lcdc: UInt8) {
            
        // Height Spite is 8x8 or 8x16,
        // Used determinate on bit 2 in LCDC reg
        let spriteHeight = (lcdc & 0x04) != 0 ? 16 : 8
            
        // Object palette (0xFF48 and 0xFF49)
        let pal0 = self.mmu.readByte(0xFF48) ?? 0
        let pal1 = self.mmu.readByte(0xFF49) ?? 0
            
        // OAM buffer contains 40 sprites, this used 4B memory
        // Y pos, X pos, tile idx, attributes
        for i in stride(from: 39, through: 0, by: -1) {
            let idx = i * 4
                
            // Read coordinate
            let yPos = Int(self.oam[idx]) - 16  // Y is shifted 16
            let xPos = Int(self.oam[idx+1]) - 8 // X is shifted 8
            
            let tileIndex  = self.oam[idx+2]
            let attributes = self.oam[idx+3]
                
            if Int(self.lineY) >= yPos && Int(self.lineY) < (yPos + spriteHeight) {
                    
                // Is outside screen, not draw this
                if xPos + 8 <= 0 || xPos >= 160 { continue }
                    
                // Flags
                let priority = (attributes & 0x80) != 0 // 1 = Under BG, 0 = Above
                let yFlip    = (attributes & 0x40) != 0 // 1 = Y Flipped
                let xFlip    = (attributes & 0x20) != 0 // 1 = X Flipped
                let usePal1  = (attributes & 0x10) != 0
                    
                let palette = usePal1 ? pal1 : pal0
                
                var lineInSprite = Int(self.lineY) - yPos
                    
                // Manage Vertical flip
                if yFlip { lineInSprite = spriteHeight - 1 - lineInSprite }
                
                // Tile Data address
                // The sprites used unsigned mode 0x8000
                // If used in 8x16 mode, the less significant bit in the index is ignored
                var tIndex = tileIndex
                if spriteHeight == 16 {
                    tIndex = tileIndex & 0xFE // Base Tile (is ever odd)
                    
                    if lineInSprite >= 8 {
                        tIndex = tIndex + 1
                        lineInSprite = lineInSprite - 8
                    }
                }
                let tileAddr = 0x8000 + UInt16(tIndex) * 16 + UInt16(lineInSprite * 2)
                
                let byte1 = readVRAM(tileAddr)
                let byte2 = readVRAM(tileAddr + 1)
                
                // Draw the horizontal 8 pixel sprite
                for x in 0..<8 {
                    let pixelX = xPos + x
                    
                    // If pixel is outside on the screen, skip
                    if pixelX < 0 || pixelX >= 160 { continue }
                    
                    // Manage Horizontal Flip
                    let bitIndex = xFlip ? x : (7 - x)
                    let bitLow  = (byte1 >> bitIndex) & 0x01
                    let bitHigh = (byte2 >> bitIndex) & 0x01
                    let colorID = (bitHigh << 1) | bitLow
                    
                    // Transparent: Color 0 is transparent
                    if colorID == 0 { continue }
                    
                    if priority && bgPriorityBuffer[pixelX] != 0 { continue }
                    
                    let realColor = getPaletteColor(colorID: colorID, palette: palette)
                    putPixel(x: pixelX, color: realColor)
                }
            }
        }
    }
        
    // MARK: - Handled
        
    @inline(__always)
    private func getPaletteColor(
        colorID: UInt8,
        palette: UInt8
    ) -> (UInt8, UInt8, UInt8) {
            
        // The palenne have 4 colors, 2 bit for each color
        // Extract the exect 2 bit for the color ID
        let shift    = colorID * 2
        let mappedID = (palette >> shift) & 0x03
            
        switch mappedID {
            case 0 : return (255, 255, 255) // White
            case 1 : return (170, 170, 170) // Light gray
            case 2 : return ( 85,  85,  85) // Dark gray
            case 3 : return (  0,   0,   0) // Black
            default: return (255, 255, 255)
        }
    }
        
    @inline(__always)
    private func putPixel(x: Int, color: (UInt8, UInt8, UInt8)) {
        let index = (Int(lineY) * 160 + x) * 4
            
        frameBuffer[index]     = color.0
        frameBuffer[index + 1] = color.1
        frameBuffer[index + 2] = color.2
        frameBuffer[index + 3] = 255
    }
}
