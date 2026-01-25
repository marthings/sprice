import SwiftUI
import AppKit
import Charts

// MARK: - Chart Configuration

enum ChartConfiguration {
    case menuBar
    case fullSize
    
    var height: CGFloat {
        switch self {
        case .menuBar: return 180
        case .fullSize: return 260
        }
    }
    
    var showXAxisLabels: Bool {
        switch self {
        case .menuBar: return false
        case .fullSize: return true
        }
    }
}

// MARK: - Reusable Chart Component

struct SpotPriceBarChart: View {
    let dayData: SpotPriceViewModel.DayChartData
    let configuration: ChartConfiguration
    @State private var selectedDate: Date?
    
    var body: some View {
        Chart {
            ForEach(dayData.buckets) { bucket in
                BarMark(
                    xStart: .value("Start", bucket.start),
                    xEnd: .value("End", bucket.end),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(bucket.category.color)
                .cornerRadius(2)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.5)
            }
            
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, spacing: 0) {
                        CalloutView(
                            title: "\(timeLabel(bucket.start))–\(timeLabel(bucket.end))",
                            value: "\(Int(bucket.orePerKWh.rounded())) öre/kWh",
                            color: bucket.category.color
                        )
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: dayData.minOre...max(dayData.maxOre, dayData.minOre + 1))
        .chartXAxis {
            if configuration.showXAxisLabels {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(date.formatted(.dateTime.hour()))
                    }
                }
            }
        }
        .frame(height: configuration.height)
    }
    
    // MARK: - Helper Methods
    
    private func calendarBounds(for date: Date?) -> ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: date ?? Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return start...end
    }
    
    private func findBucket(for date: Date, in buckets: [SpotPriceViewModel.PriceBucket]) -> SpotPriceViewModel.PriceBucket? {
        buckets.first { $0.start <= date && $0.end > date }
    }
    
    private func isBucketSelected(_ bucket: SpotPriceViewModel.PriceBucket, selectedDate: Date?) -> Bool {
        guard let selectedDate else { return true }
        return bucket.start <= selectedDate && bucket.end > selectedDate
    }
    
    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

private struct CalloutView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(value).font(.caption).bold().monospacedDigit()
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 2)
    }
}

// AppDelegate to handle app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock - makes this a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct SpotpriceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = SpotPriceViewModel()
    @StateObject private var summaryViewModel = SummaryViewModel() 
    
    var body: some Scene {
        // Menu bar only app - no WindowGroup needed
        
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
            .presentationBackground(.ultraThinMaterial)
                .preferredColorScheme(.dark)
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
