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
            VStack(spacing: 16) {
                // Weekly Summary
                MenuBarSummaryView(viewModel: summaryViewModel)
                
                // Spot Price Chart
                if case .loaded(let payload) = viewModel.state {
                    SpotPriceBarChart(dayData: payload.day, configuration: .menuBar)
                } else {
                    // Loading or error state
                    VStack(spacing: 12) {
                        if case .loading = viewModel.state {
                            ProgressView()
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: "bolt.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(loadingStatusText)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 280, height: 280)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button("Uppdatera") {
                        Task { 
                            await viewModel.load() 
                            await summaryViewModel.loadSummary()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.state == .loading)
                    
                    Button("Avsluta") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 320) // Slightly wider to accommodate summary
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
    
    private var loadingStatusText: String {
        switch viewModel.state {
        case .idle:
            return "Tryck Uppdatera för att ladda spotpriser"
        case .loading:
            return "Laddar spotpriser..."
        case .failed(let message):
            return message
        case .loaded:
            return ""
        }
    }
}

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay // Ex: "42"
        }
        return "--"
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

// MARK: - Menu Bar Summary View

struct MenuBarSummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("Veckans elmarknadsläge")
                    .font(.subheadline.bold())
                Spacer()
            }
            
            switch viewModel.state {
            case .idle:
                Text("Tryck Uppdatera för att ladda summeringen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                
            case .loadingURL, .fetchingReport, .summarizing:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(loadingText(for: viewModel.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
            case .loaded(let summary, let url):
                Text(summary)
                    .font(.caption)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Link("Läs hela rapporten", destination: url)
                    .font(.caption2)
                    .padding(.top, 2)
                
            case .failed(let error):
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Kunde inte hämta summeringen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func loadingText(for state: SummaryViewModel.State) -> String {
        switch state {
        case .loadingURL: return "Beräknar veckoadress..."
        case .fetchingReport: return "Hämtar veckorapport..."
        case .summarizing: return "Summerar med AI..."
        default: return "Laddar..."
        }
    }
}
