import SwiftUI
import Charts

struct SpotPriceBarChart: View {
    let dayData: SpotPriceViewModel.DayChartData
    let configuration: ChartConfiguration
    
    @State private var selectedDate: Date?
    
    struct ChartConfiguration {
        let height: CGFloat
        let showLegend: Bool
        let showCurrentPrice: Bool
        let showAxes: Bool
        let isCompact: Bool
        
        static let full = ChartConfiguration(
            height: 200,
            showLegend: true,
            showCurrentPrice: true,
            showAxes: true,
            isCompact: false
        )
        
        static let menuBar = ChartConfiguration(
            height: 120,
            showLegend: false,
            showCurrentPrice: true,
            showAxes: false,
            isCompact: true
        )
        
        static let widget = ChartConfiguration(
            height: 80,
            showLegend: false,
            showCurrentPrice: false,
            showAxes: false,
            isCompact: true
        )
    }
    
    init(dayData: SpotPriceViewModel.DayChartData, configuration: ChartConfiguration = .full) {
        self.dayData = dayData
        self.configuration = configuration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: configuration.isCompact ? 8 : 12) {
            // Current price header (if enabled)
            if configuration.showCurrentPrice {
                currentPriceHeader
            }
            
            // Legend (if enabled)
            if configuration.showLegend {
                legend
            }
            
            // Chart
            chartView
        }
    }
    
    @ViewBuilder
    private var currentPriceHeader: some View {
        if let current = dayData.currentBucket {
            HStack {
                Text("Nu: \(Int(current.orePerKWh)) öre/kWh")
                    .font(configuration.isCompact ? .caption.bold() : .title3.bold())
                Spacer()
                if !configuration.isCompact {
                    Text("Min: \(Int(dayData.minOre)) • Max: \(Int(dayData.maxOre))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, text: "Lågt")
            legendItem(color: .yellow, text: "Medel")
            legendItem(color: .red, text: "Högt")
            Spacer()
            if !configuration.isCompact {
                Text("Gränser: ≤\(Int(dayData.thresholds.lowUpper)) / ≤\(Int(dayData.thresholds.mediumUpper)) öre")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        Chart {
            ForEach(dayData.buckets) { bucket in
                BarMark(
                    xStart: .value("Start", bucket.start),
                    xEnd: .value("End", bucket.end),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(color(for: bucket.category))
                .cornerRadius(configuration.isCompact ? 1 : 2)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.5)
            }
            
            // Selection indicator and annotation
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, spacing: 0) {
                        if !configuration.isCompact {
                            CalloutView(
                                title: "\(timeLabel(bucket.start))–\(timeLabel(bucket.end))",
                                value: "\(Int(bucket.orePerKWh.rounded())) öre/kWh",
                                color: color(for: bucket.category)
                            )
                        }
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartXSelection(value: configuration.isCompact ? .constant(nil) : $selectedDate)
        .chartYScale(domain: dayData.minOre...max(dayData.maxOre, dayData.minOre + 1))
        .if(configuration.showAxes) { chart in
            chart.chartXAxis {
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
    
    // MARK: - Helper Functions
    
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
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: configuration.isCompact ? 6 : 10, height: configuration.isCompact ? 6 : 10)
            Text(text).font(configuration.isCompact ? .caption2 : .caption).foregroundStyle(.secondary)
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
}

// MARK: - Supporting Views

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

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Full Chart") {
    // Create some sample data for preview
    let sampleBuckets = (0..<24).map { hour in
        let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? Date()
        let price = Double.random(in: 50...200)
        let category: SpotPriceViewModel.PriceCategory = price < 80 ? .low : price < 120 ? .medium : .high
        
        return SpotPriceViewModel.PriceBucket(
            start: start,
            end: end,
            orePerKWh: price,
            category: category
        )
    }
    
    let sampleData = SpotPriceViewModel.DayChartData(
        buckets: sampleBuckets,
        thresholds: SpotPriceViewModel.Thresholds(lowUpper: 80, mediumUpper: 120),
        minOre: 50,
        maxOre: 200
    )
    
    VStack(spacing: 20) {
        SpotPriceBarChart(dayData: sampleData, configuration: .full)
            .padding()
            .background(.white)
            .cornerRadius(12)
            .shadow(radius: 4)
        
        SpotPriceBarChart(dayData: sampleData, configuration: .menuBar)
            .padding()
            .background(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
    .padding()
    .background(.blue.gradient)
}