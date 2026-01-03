//
//  GameControllerManager.swift
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 03/01/26.
//

import GameController
import Combine

class GameControllerManager: ObservableObject {
    var gameboy: GameBoy?
    
    init() {
        // Set observer for pad
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        // Set observer for keyboard
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidConnect),
            name: .GCKeyboardDidConnect,
            object: nil
        )
        
        // Start scanning
        startLooking()
    }
    
    func startLooking() {
        // Control exist pad connected
        for controller in GCController.controllers() {
            setupControllerMapping(controller)
        }
        
        // Control exist keyboard connected
        if let keyboard = GCKeyboard.coalesced {
            setupKeyboardMapping(keyboard)
        }
    }
    
    @objc func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
                
        setupControllerMapping(controller)
    }
    
    func setupControllerMapping(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
            
        
        gamepad.buttonA.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.a) : self.gameboy?.keyUp(.a)
        }
            
        gamepad.buttonB.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.b) : self.gameboy?.keyUp(.b)
        }
            
        gamepad.buttonMenu.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.start) : self.gameboy?.keyUp(.start)
        }
            
        gamepad.buttonOptions?.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.select) : self.gameboy?.keyUp(.select)
        }
            
        // MARK: - Joypad D-pad
        
        gamepad.dpad.up.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.up) : self.gameboy?.keyUp(.up)
        }
            
        gamepad.dpad.down.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.down) : self.gameboy?.keyUp(.down)
        }
            
        gamepad.dpad.left.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.left) : self.gameboy?.keyUp(.left)
        }
            
        gamepad.dpad.right.valueChangedHandler = { (button, value, pressed) in
            pressed ? self.gameboy?.keyDown(.right) : self.gameboy?.keyUp(.right)
        }
    }
    
    
    
    @objc func keyboardDidConnect(_ notification: Notification) {
        guard let keyboard = notification.object as? GCKeyboard else { return }
        setupKeyboardMapping(keyboard)
    }
        
    func setupKeyboardMapping(_ keyboard: GCKeyboard) {
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] (input, changedKey, keyCode, pressed) in
                
            switch keyCode {
                
                // MARK: - Keyboard D-pad
                    
                case .upArrow:
                    pressed ? self?.gameboy?.keyDown(.up) : self?.gameboy?.keyUp(.up)
                
                case .downArrow:
                    pressed ? self?.gameboy?.keyDown(.down) : self?.gameboy?.keyUp(.down)
                
                case .leftArrow:
                    pressed ? self?.gameboy?.keyDown(.left) : self?.gameboy?.keyUp(.left)
                
                case .rightArrow:
                    pressed ? self?.gameboy?.keyDown(.right) : self?.gameboy?.keyUp(.right)
                    
                // MARK: - Keyboard Buttons
              
                case .keyX:
                    pressed ? self?.gameboy?.keyDown(.a) : self?.gameboy?.keyUp(.a)
                        
                case .keyZ:
                    pressed ? self?.gameboy?.keyDown(.b) : self?.gameboy?.keyUp(.b)
                        
                case .returnOrEnter:
                    pressed ? self?.gameboy?.keyDown(.start) : self?.gameboy?.keyUp(.start)
                        
                case .spacebar, .deleteOrBackspace:
                    pressed ? self?.gameboy?.keyDown(.select) : self?.gameboy?.keyUp(.select)
                        
                default:
                    break
            }
        }
    }
}
