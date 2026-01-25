//
//  ContentView.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//

import SwiftUI
import Charts

struct ContentView: View {
    
    @StateObject private var viewModel = SpotPriceViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView {
                    Text("Hämtar spotpris…")
                }
                .progressViewStyle(.circular)
                .tint(.accentColor)
                .padding(.top, 12)
            
            case .loaded(let payload):
                VStack(alignment: .leading, spacing: 12) {
                    Text("Spotpriset nu: \(payload.currentDisplay)")
                        .font(.title3)
                        .bold()
                    
                    // Legend
                    HStack(spacing: 12) {
                        legendDot(color: .green)
                        Text("Lågt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        legendDot(color: .yellow)
                        Text("Medel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        legendDot(color: .red)
                        Text("Högt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        // Optional: show thresholds used (rounded)
                        let lowUp = Int(payload.day.thresholds.lowUpper.rounded())
                        let medUp = Int(payload.day.thresholds.mediumUpper.rounded())
                        Text("Gränser: ≤\(lowUp) / ≤\(medUp) öre")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Chart
                    Chart(payload.day.buckets) { bucket in
                        BarMark(
                            xStart: .value("Start", bucket.start),
                            xEnd: .value("End", bucket.end),
                            y: .value("Pris (öre/kWh)", bucket.orePerKWh)
                        )
                        .foregroundStyle(color(for: bucket.category))
                        .cornerRadius(2)
                    }
                    .chartYScale(domain: payload.day.minOre...max(payload.day.maxOre, payload.day.minOre + 1))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 260)
                    .animation(.default, value: payload.day.buckets)
                }
            
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
        .padding(24)
        .task {
            await viewModel.load()
        }
    }
    
    private func color(for category: SpotPriceViewModel.PriceCategory) -> Color {
        switch category {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    private func legendDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}


#Preview {
    ContentView()
}
