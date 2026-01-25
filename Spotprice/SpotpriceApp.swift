import SwiftUI
import AppKit
import Charts

@main
struct SpotpriceApp: App {
    @StateObject private var viewModel = SpotPriceViewModel()
    @StateObject private var summaryViewModel = SummaryViewModel() 
    
    var body: some Scene {
        // Din vanliga fönster-vy
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(summaryViewModel) 
        }
        
        // Här lägger vi till menyraden
        MenuBarExtra {
            // Innehållet i menyn när man klickar på den
            VStack(alignment: .leading, spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktuellt spotpris")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.state.currentPriceLabel + " öre")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Chart showing upcoming prices
                if case .loaded(let payload) = viewModel.state {
                    let chartData = payload.day.upcomingBuckets(limit: 8)
                    if !chartData.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kommande timmar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Chart(chartData) { bucket in
                                BarMark(
                                    x: .value("Time", bucket.start, unit: .hour),
                                    y: .value("Price", bucket.orePerKWh)
                                )
                                .foregroundStyle(bucket.category.color)
                                .cornerRadius(2)
                            }
                            .frame(height: 80)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour)) { value in
                                    if let date = value.as(Date.self) {
                                        AxisValueLabel {
                                            Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel {
                                        if let price = value.as(Double.self) {
                                            Text("\(Int(price))")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Inga kommande priser tillgängliga")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                } else {
                    // Loading or error state
                    HStack {
                        if case .loading = viewModel.state {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chart.bar")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(viewModel.state == .loading ? "Laddar..." : "Tryck Uppdatera för att se graf")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Buttons
                HStack {
                    Button("Uppdatera") {
                        Task { 
                            await viewModel.load() 
                            await summaryViewModel.loadSummary()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button("Avsluta") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 280)
        } label: {
            // Enklare label för topbaren
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                
                Text(viewModel.state.currentPriceLabel)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .menuBarExtraStyle(.window)
        // Säkerställ att samma viewModel också finns i menyns miljö om under-vyer skulle behöva den
        .environmentObject(viewModel)
        .environmentObject(summaryViewModel) 
    }
}

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay // Ex: "42 öre"
        }
        return "--"
    }
    
    var debugDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .loaded(let payload):
            return "loaded (\(payload.day.buckets.count) buckets)"
        case .failed(let message):
            return "failed: \(message)"
        }
    }
}

extension SpotPriceViewModel.DayChartData {
    func upcomingBuckets(limit: Int) -> [SpotPriceViewModel.PriceBucket] {
        let now = Date()
        let upcoming = buckets.filter { $0.start >= now }
        
        // If no upcoming buckets, return the last few buckets for display
        if upcoming.isEmpty {
            return Array(buckets.suffix(limit))
        }
        
        return Array(upcoming.prefix(limit))
    }
}

extension SpotPriceViewModel.PriceCategory {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
