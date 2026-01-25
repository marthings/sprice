//
//  ContentView.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = SpotPriceViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .idle, .loading:
                Text("Hämtar spotpris…")
                    .foregroundStyle(.secondary)
            case .loaded(let display):
                Text("Spotpriset nu: \(display)")
                    .font(.title3)
                    .bold()
            case .failed(let errorText):
                VStack(spacing: 8) {
                    Text("Kunde inte hämta spotpris")
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Försök igen") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(48)
        .task {
            await viewModel.load()
        }
    }
}


#Preview {
    ContentView()
}
