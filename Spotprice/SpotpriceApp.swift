import SwiftUI
import AppKit
import Charts

// MARK: - Chart Configuration

enum ChartConfiguration {
    case menuBar
    case fullSize
    
    var height: CGFloat {
        switch self {
        case .menuBar: return 200
        case .fullSize: return 300
        }
    }
    
    var showXAxisLabels: Bool {
        switch self {
        case .menuBar: return true
        case .fullSize: return true
        }
    }
    
    var showYAxisLabels: Bool {
        switch self {
        case .menuBar: return true
        case .fullSize: return true
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .menuBar: return 12
        case .fullSize: return 16
        }
    }
}

// MARK: - Reusable Chart Component

struct SpotPriceBarChart: View {
    let dayData: SpotPriceViewModel.DayChartData
    let configuration: ChartConfiguration
    @State private var selectedDate: Date?
    @State private var hoveredBucket: SpotPriceViewModel.PriceBucket?
    
    var body: some View {
        VStack(spacing: 0) {
            // Chart title and current price
            chartHeader
                .padding(.horizontal)
            // Main chart
            chartContent
        }
    }
    
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Spotpris idag")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if let current = currentPriceBucket {
                    Text("\(Int(current.orePerKWh.rounded())) öre/kWh")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(current.category.color)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Nästa timme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let next = nextPriceBucket {
                    HStack(spacing: 4) {
                        priceChangeIndicator(current: currentPriceBucket?.orePerKWh, next: next.orePerKWh)
                        Text("\(Int(next.orePerKWh.rounded()))")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(next.category.color)
                    }
                }
            }
        }

        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var chartContent: some View {
        Chart {
            // Area fill under the line
            ForEach(dayData.buckets) { bucket in
                AreaMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            dynamicGradientColor(for: bucket).opacity(0.4),
                            dynamicGradientColor(for: bucket).opacity(0.1),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.3)
            }
            
            // Main line with smooth curves
            ForEach(dayData.buckets) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(dynamicGradientColor(for: bucket))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.4)
                .accessibilityLabel("Pris \(Int(bucket.orePerKWh.rounded())) öre per kWh klockan \(timeLabel(bucket.start))")
                .accessibilityValue("\(bucket.category.description)")
            }
            
            // Data point circle - only for selected/hovered bucket
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                PointMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(dynamicGradientColor(for: bucket))
                .symbolSize(64)
                .symbol(.circle)
            }
            
            // Current time indicator
            if let now = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) {
                RuleMark(x: .value("Nu", now))
                    .foregroundStyle(.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .accessibilityLabel("Nuvarande tid")
            }
            
            // Selection indicator
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit, y: .disabled)) {
                        modernCallout(for: bucket)
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartYScale(domain: 0...max(dayData.maxOre * 1.1, dayData.minOre + 10))
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            if configuration.showXAxisLabels {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.hour()))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            if configuration.showYAxisLabels {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text("\(Int(price.rounded()))")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: configuration.height)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Convert gesture location to chart coordinates for better interaction
                    withAnimation(.easeOut(duration: 0.2)) {
                        updateSelection(at: value.location)
                    }
                }
        )
    }
    
    private func modernCallout(for bucket: SpotPriceViewModel.PriceBucket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(bucket.category.gradientColor)
                    .frame(width: 10, height: 10)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            HStack(spacing: 6) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(bucket.category.color)
                Text("öre/kWh")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(bucket.category.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(bucket.category.color.opacity(0.1), in: Capsule())
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var currentPriceBucket: SpotPriceViewModel.PriceBucket? {
        let now = Date()
        return dayData.buckets.first { $0.start <= now && $0.end > now }
    }
    
    private var nextPriceBucket: SpotPriceViewModel.PriceBucket? {
        let now = Date()
        return dayData.buckets.first { $0.start > now }
    }
    
    private func priceChangeIndicator(current: Double?, next: Double?) -> some View {
        guard let current, let next else {
            return AnyView(EmptyView())
        }
        
        let change = next - current
        let isIncrease = change > 0
        let icon = isIncrease ? "arrow.up" : change < 0 ? "arrow.down" : "minus"
        let color: Color = isIncrease ? .red : change < 0 ? .green : .secondary
        
        return AnyView(
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        )
    }
    
    private func updateSelection(at location: CGPoint) {
        // This is a simplified version - in a real implementation,
        // you'd convert the location to chart coordinates
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let hourProgress = location.x / 300 // Approximate chart width
        let selectedHour = Int(hourProgress * 24)
        
        if let selectedDate = Calendar.current.date(byAdding: .hour, value: selectedHour, to: startOfDay) {
            self.selectedDate = selectedDate
        }
    }
    
    // MARK: - Helper Methods
    
    private func dynamicGradientColor(for bucket: SpotPriceViewModel.PriceBucket) -> Color {
        // Create a smooth color transition based on price level
        let normalizedPrice = (bucket.orePerKWh - dayData.minOre) / (dayData.maxOre - dayData.minOre)
        
        if normalizedPrice <= 0.33 {
            // Low prices: Green to Yellow-Green
            return Color.green.interpolated(to: .yellow, by: normalizedPrice * 3)
        } else if normalizedPrice <= 0.66 {
            // Medium prices: Yellow to Orange
            return Color.yellow.interpolated(to: .orange, by: (normalizedPrice - 0.33) * 3)
        } else {
            // High prices: Orange to Red
            return Color.orange.interpolated(to: .red, by: (normalizedPrice - 0.66) * 3)
        }
    }
    
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
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
    }
}

// MARK: - Modern Menu Bar View
struct ModernMenuBarView: View {
    @ObservedObject var viewModel: SpotPriceViewModel
    @ObservedObject var summaryViewModel: SummaryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app branding
            menuHeader
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // Weekly Summary with glass effect and update button
                    MenuBarSummaryView(viewModel: summaryViewModel, spotPriceViewModel: viewModel)

                    
                    // Chart section
                    chartSection
                        .glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: 16))
                    // Quick stats
                    quickStats
                }
                .padding(20)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .frame(width: 380, height: 680)
    }
    
    private var menuHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange.gradient)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeat(.continuous))
                
                Text("Spotpris")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Avsluta-knapp med stäng-ikon
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Avsluta")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var chartSection: some View {
        VStack(spacing: 0) {
            if case .loaded(let payload) = viewModel.state {
                SpotPriceBarChart(dayData: payload.day, configuration: .menuBar)
            } else {
                loadingStateView
                    .frame(height: 200)
            }
        }
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            Group {
                if case .loading = viewModel.state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .tint(.orange)
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            
            Text(loadingStatusText)
                .font(.headline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var quickStats: some View {
        if case .loaded(let payload) = viewModel.state {
            VStack(spacing: 16) {
                // Original stat cards
                HStack(spacing: 12) {
                    statCard(
                        title: "Lägsta pris",
                        value: "\(Int(payload.day.minOre.rounded()))",
                        unit: "öre",
                        color: .green,
                        icon: "arrow.down.circle.fill"
                    )
                    
                    statCard(
                        title: "Högsta pris", 
                        value: "\(Int(payload.day.maxOre.rounded()))",
                        unit: "öre",
                        color: .red,
                        icon: "arrow.up.circle.fill"
                    )
                    
                    statCard(
                        title: "Medelpris",
                        value: "\(Int(averagePrice(payload.day.buckets).rounded()))",
                        unit: "öre",
                        color: .blue,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                
                // Cost calculation section
                costCalculationSection(payload: payload)
            }
        }
    }
    
    private func statCard(title: String, value: String, unit: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .glassEffect(.regular.tint(color.opacity(0.1)), in: .rect(cornerRadius: 12))
    }
    
    private func costCalculationSection(payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Med elpriset idag kostar...")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                costCard(
                    title: "En dusch",
                    mainCost: calculateCost(kWh: 6.0, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 6.0, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 6.0, price: payload.day.minOre),
                    description: "10 min, 160 liter vatten ≈ ~6 kWh",
                    icon: "drop.fill"
                )
                
                costCard(
                    title: "Baka en pizza",
                    mainCost: calculateCost(kWh: 1.1, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 1.1, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 1.1, price: payload.day.minOre),
                    description: "Ugn i 30 min ≈ ~1,1 kWh",
                    icon: "triangle.fill"
                )
                
                costCard(
                    title: "En värmepump dygnet runt",
                    mainCost: calculateCost(kWh: 24.0, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 24.0, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 24.0, price: payload.day.minOre),
                    description: "1000W × 24 timmar = 24 kWh",
                    icon: "thermometer"
                )
                
                costCard(
                    title: "Ett bad",
                    mainCost: calculateCost(kWh: 7.5, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 7.5, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 7.5, price: payload.day.minOre),
                    description: "200 liter vatten ≈ ~7,5 kWh",
                    icon: "bathtub.fill"
                )
                
                costCard(
                    title: "Koka 1 liter vatten",
                    mainCost: calculateCost(kWh: 0.12, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 0.12, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 0.12, price: payload.day.minOre),
                    description: "Varmplatta i 4 min ≈ ~0,12 kWh",
                    icon: "drop"
                )
                
                costCard(
                    title: "Ladda elbilen",
                    mainCost: calculateCost(kWh: 45.0, currentPrice: getCurrentPrice(payload)),
                    highCost: calculateCost(kWh: 45.0, price: payload.day.maxOre),
                    lowCost: calculateCost(kWh: 45.0, price: payload.day.minOre),
                    description: "Tesla Model 3 10-80% ≈ ~45 kWh",
                    icon: "car.fill"
                )
            }
        }
        .padding(.top, 8)
    }
    
    private func costCard(title: String, mainCost: String, highCost: String, lowCost: String, description: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(mainCost)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("kr")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            // High/Low price comparison
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(highCost + " kr")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.red)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(lowCost + " kr")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
            
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: 12))
    }
    
    private func calculateCost(kWh: Double, currentPrice: Double) -> String {
        // Convert öre/kWh to kr and calculate total cost
        let costInKr = (currentPrice / 100.0) * kWh
        return String(format: "%.2f", costInKr)
    }
    
    private func calculateCost(kWh: Double, price: Double) -> String {
        // Convert öre/kWh to kr and calculate total cost
        let costInKr = (price / 100.0) * kWh
        return String(format: "%.2f", costInKr)
    }
    
    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        let now = Date()
        if let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) {
            return currentBucket.orePerKWh
        }
        return averagePrice(payload.day.buckets)
    }
    
    
    private func averagePrice(_ buckets: [SpotPriceViewModel.PriceBucket]) -> Double {
        let sum = buckets.reduce(0) { $0 + $1.orePerKWh }
        return sum / Double(buckets.count)
    }
    
    private var loadingStatusText: String {
        switch viewModel.state {
        case .idle:
            return "Tryck Uppdatera för att ladda dagens spotpriser"
        case .loading:
            return "Hämtar aktuella spotpriser..."
        case .failed(let message):
            return message
        case .loaded:
            return ""
        }
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
            // Modern dropdown interface
            ModernMenuBarView(viewModel: viewModel, summaryViewModel: summaryViewModel)
        } label: {
            // Enhanced menu bar label with live data
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(viewModel.state.labelColor.gradient)
                    .symbolEffect(.pulse.wholeSymbol, isActive: viewModel.state == .loading)
                
                Text(viewModel.state.currentPriceLabel)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.state.labelColor)
                
                if case .loaded = viewModel.state {
                    Text("öre")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuBarExtraStyle(.window)
        .environmentObject(viewModel)
        .environmentObject(summaryViewModel)
    }
}

extension Color {
    /// Interpolates between two colors by a given factor (0.0 to 1.0)
    func interpolated(to color: Color, by factor: Double) -> Color {
        let clampedFactor = max(0, min(1, factor))
        
        // Convert to RGB components (simplified approach)
        let fromComponents = self.rgbComponents()
        let toComponents = color.rgbComponents()
        
        let red = fromComponents.red + (toComponents.red - fromComponents.red) * clampedFactor
        let green = fromComponents.green + (toComponents.green - fromComponents.green) * clampedFactor
        let blue = fromComponents.blue + (toComponents.blue - fromComponents.blue) * clampedFactor
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private func rgbComponents() -> (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let convertedColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (Double(convertedColor.redComponent), Double(convertedColor.greenComponent), Double(convertedColor.blueComponent))
        #else
        return (0.5, 0.5, 0.5) // Fallback
        #endif
    }
}

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay // Ex: "42"
        }
        return "--"
    }
    
    var labelColor: Color {
        if case .loaded(let payload) = self {
            // Find current price bucket to determine color
            let now = Date()
            if let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) {
                return currentBucket.category.color
            }
        }
        return .secondary
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
    
    var gradientColor: LinearGradient {
        switch self {
        case .low:
            return LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .top, endPoint: .bottom)
        case .medium:
            return LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .top, endPoint: .bottom)
        case .high:
            return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom)
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Lågt pris"
        case .medium:
            return "Medelpris"
        case .high:
            return "Högt pris"
        }
    }
}

// MARK: - Menu Bar Summary View

struct MenuBarSummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @ObservedObject var spotPriceViewModel: SpotPriceViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with modern styling
            HStack(spacing: 8) {

                Text("Månadens elmarknadsläge")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Uppdatera-knapp
                Button(action: {
                    Task {
                        await spotPriceViewModel.load()
                        await viewModel.loadSummary()
                    }
                }) {
                    HStack(spacing: 4) {
                        if spotPriceViewModel.state == .loading || viewModel.state.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                        }

                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.gradient, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(spotPriceViewModel.state == .loading || viewModel.state.isLoading)
            }
            
            // Content based on state
            contentView
        }

    }
    
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text("Tryck Uppdatera för att hämta månadens marknadsöversikt")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
        case .loadingURL, .fetchingReport, .summarizing:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.mini)
                        .tint(.blue)
                    
                    Text(loadingText(for: viewModel.state))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                
                // Progress bar
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.blue.gradient)
                                .frame(width: geometry.size.width * progressValue, height: 3)
                                .animation(.easeInOut(duration: 0.3), value: progressValue)
                        }
                }
                .frame(height: 3)
            }
            
        case .loaded(let summary, let url, let isPreviousMonth):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: isPreviousMonth ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isPreviousMonth ? .orange : .green)
                    
                    Text(isPreviousMonth ? "Föregående månad" : "Uppdaterad")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                Text(summary)
                    .font(.caption.weight(.medium))
                    .lineLimit(isPreviousMonth ? 6 : 4) // Mer plats för notisen om föregående månad
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("Läs hela rapporten")
                            .font(.caption2.weight(.semibold))
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            
        case .failed(let error):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text("Kunde inte hämta marknadsöversikten")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressValue: Double {
        switch viewModel.state {
        case .loadingURL:
            return 0.3
        case .fetchingReport:
            return 0.6
        case .summarizing:
            return 0.9
        default:
            return 0.0
        }
    }
    
    private func loadingText(for state: SummaryViewModel.State) -> String {
        switch state {
        case .loadingURL: return "Förbereder månadsdata..."
        case .fetchingReport: return "Hämtar marknadsrapport..."
        case .summarizing: return "Analyserar med AI..."
        default: return "Laddar..."
        }
    }
}

// MARK: - Summary View Model Extensions

extension SummaryViewModel.State {
    var isLoading: Bool {
        switch self {
        case .loadingURL, .fetchingReport, .summarizing:
            return true
        default:
            return false
        }
    }
}
