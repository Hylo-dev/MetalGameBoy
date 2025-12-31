import SwiftUI

struct ContentView: View {
    // Nota: Ora GameBoy deve essere una classe (Reference Type) condivisa
    let gameboy = GameBoy()
    @State private var isRunning = false
    
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
    }
    
    func bootGame() {
        guard let url = Bundle.main.url(forResource: "tetris", withExtension: "gb") else { return }
        do {
            let data = try Data(contentsOf: url)
            if gameboy.boot(romData: data) {
                isRunning = true
            }
        } catch { print("Errore: \(error)") }
    }
}
