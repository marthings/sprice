import SwiftUI

@main
struct SpotpriceApp: App {
    @StateObject private var viewModel = SpotPriceViewModel()
    
    var body: some Scene {
        // Din vanliga fönster-vy
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        
        // Här lägger vi till menyraden
        MenuBarExtra {
            // Innehållet i menyn när man klickar på den
            VStack {
                Text("Aktuellt spotpris")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(viewModel.state.currentPriceLabel)
                    .font(.headline)
                
                Divider()
                
                Button("Uppdatera") {
                    Task { await viewModel.load() }
                }
                
                Button("Avsluta") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        } label: {
            // Det som faktiskt syns i topbaren hela tiden
            HStack {
                Image(systemName: "bolt.fill")
                Text(viewModel.state.currentPriceLabel)
            }
        }
    }
}

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay // Ex: "42 öre"
        }
        return "-- öre"
    }
}
