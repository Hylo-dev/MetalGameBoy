import SwiftUI

struct ContentView: View {
    let gameboy = GameBoy()
    
    @StateObject
    private var inputManager = GameControllerManager()
    
    @State
    private var isRunning = false
    
    @FocusState
    private var isFocused: Bool
    
    var body: some View {
        VStack {
            Text("MetalGameBoy")
                .font(.largeTitle)
            
            // IL TUO NUOVO SCHERMO VELOCE
            if isRunning {
                MetalGameBoyView(gameboy: gameboy)
                    .frame(width: 160 * 2, height: 144 * 2)
                    .border(Color.gray, width: 2)
                
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 160 * 2, height: 144 * 2)
                    .overlay(Text("Premi BOOT").foregroundColor(.white))
            }
            
            HStack {
                Button("BOOT TETRIS") {
                    bootGame()
                }
                .padding()
                .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear {
            self.isFocused = true
            self.inputManager.gameboy = gameboy
            self.inputManager.startLooking()
        }
        .onKeyPress(phases: [.down, .repeat]) { _ in
            return .handled
        }
    }
    
    func bootGame() {
        guard let url = Bundle.main.url(
            forResource: "mario_land",
            withExtension: "gb"
        ) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            if gameboy.boot(romData: data) {
                isRunning = true
            }
        } catch { print("Errore: \(error)") }
    }
}
