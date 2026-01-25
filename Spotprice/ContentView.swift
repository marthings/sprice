import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var viewModel: SpotPriceViewModel
    @State private var selectedDate: Date?
    
    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Hämtar spotpris…").padding(.top, 12)
                
            case .loaded(let payload):
                VStack(alignment: .leading, spacing: 12) {
                    Text("Spotpriset nu: \(payload.currentDisplay)")
                        .font(.title3).bold()
                    
                    // Legend
                    HStack(spacing: 12) {
                        legendItem(color: .green, text: "Lågt")
                        legendItem(color: .yellow, text: "Medel")
                        legendItem(color: .red, text: "Högt")
                        Spacer()
                        Text("Gränser: ≤\(Int(payload.day.thresholds.lowUpper)) / ≤\(Int(payload.day.thresholds.mediumUpper)) öre")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    
                    Chart {
                        ForEach(payload.day.buckets) { bucket in
                            BarMark(
                                xStart: .value("Start", bucket.start),
                                xEnd: .value("End", bucket.end),
                                y: .value("Pris", bucket.orePerKWh)
                            )
                            .foregroundStyle(color(for: bucket.category))
                            .cornerRadius(2)
                            .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.5)
                        }
                        
                        if let selectedDate, let bucket = findBucket(for: selectedDate, in: payload.day.buckets) {
                            RuleMark(x: .value("Vald tid", selectedDate))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .annotation(position: .top, spacing: 0) {
                                    CalloutView(
                                        title: "\(timeLabel(bucket.start))–\(timeLabel(bucket.end))",
                                        value: "\(Int(bucket.orePerKWh.rounded())) öre/kWh",
                                        color: color(for: bucket.category)
                                    )
                                }
                        }
                    }
                    // FIX: Här låser vi x-axeln till att alltid visa 24h (från start av dag till slut)
                    .chartXScale(domain: calendarBounds(for: payload.day.buckets.first?.start))
                    .chartXSelection(value: $selectedDate)
                    .chartYScale(domain: payload.day.minOre...max(payload.day.maxOre, payload.day.minOre + 1))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel(date.formatted(.dateTime.hour()))
                            }
                        }
                    }
                    .frame(height: 260)
                }
                
            case .failed(let error):
                errorView(error)
            }
        }
        .padding(24)
        .task { await viewModel.load() }
    }
    
    // MARK: - Hjälpfunktioner för Responsivitet & Logik
    
    /// Räknar ut start och slut på dygnet för att låsa grafens bredd
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
    
    // MARK: - UI Helpers
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
    
    private func color(for category: SpotPriceViewModel.PriceCategory) -> Color {
        switch category {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
    
    @ViewBuilder
    private func errorView(_ text: String) -> some View {
        VStack(spacing: 8) {
            Text("Kunde inte hämta spotpris")
            Text(text).font(.footnote).foregroundStyle(.secondary)
            Button("Försök igen") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
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
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4)
    }
}
