import SwiftUI
import AppKit
import Charts

// MARK: - Missing View Components

struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
    }
}

extension View {
    func glassEffect(_ material: Material, in shape: some InsettableShape) -> some View {
        self.background(material, in: shape)
    }
    
    func glassEffect(_ material: Material, in shape: AnyShape) -> some View {
        self.background(material)
            .clipShape(shape)
    }
}

extension Material {
    static let regular = Material.regularMaterial
}

extension AnyShape {
    static let circle = AnyShape(Circle())
    static let capsule = AnyShape(Capsule())
}

// MARK: - Chart Configuration

enum ChartConfiguration {
    case menuBar
    case fullSize
    
    var height: CGFloat {
        switch self {
        case .menuBar: return 160
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
        case .menuBar: return 10
        case .fullSize: return 16
        }
    }
}

// MARK: - Reusable Chart Component

struct SpotPriceBarChart: View {
    let dayData: DayChartData
    let configuration: ChartConfiguration
    @State private var selectedDate: Date?
    @State private var hoveredBucket: PriceBucket?
    
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pris nu")
                    .font(.custom("Avenir", size: 12).weight(.medium))
                    .foregroundStyle(.secondary)
                
                if let current = currentPriceBucket {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int(current.orePerKWh.rounded()))")
                            .font(.custom("Avenir", size: 20).weight(.bold).monospacedDigit())
                            .foregroundStyle(current.category.color)
                        Text("öre/kWh")
                            .font(.custom("Avenir", size: 11).weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Nästa")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
                
                if let next = nextPriceBucket {
                    HStack(spacing: 4) {
                        priceChangeIndicator(current: currentPriceBucket?.orePerKWh, next: next.orePerKWh)
                        Text("\(Int(next.orePerKWh.rounded()))")
                            .font(.custom("Avenir", size: 12).weight(.semibold).monospacedDigit())
                            .foregroundStyle(next.category.color)
                    }
                }
            }
        }

        .padding(.top, 8)
        .padding(.bottom, 16)
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
                                .font(.custom("Avenir", size: 10).weight(.medium))
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
                                .font(.custom("Avenir", size: 10).weight(.medium))
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
    
    private func modernCallout(for bucket: PriceBucket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(bucket.category.gradientColor)
                    .frame(width: 8, height: 8)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(.custom("Avenir", size: 11).weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            HStack(spacing: 6) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(.custom("Avenir", size: 16).weight(.bold).monospacedDigit())
                    .foregroundStyle(bucket.category.color)
                Text("öre/kWh")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(bucket.category.description)
                .font(.custom("Avenir", size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bucket.category.color.opacity(0.1), in: Capsule())
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("Surface"))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
    
    private var currentPriceBucket: PriceBucket? {
        let now = Date()
        return dayData.buckets.first { $0.start <= now && $0.end > now }
    }
    
    private var nextPriceBucket: PriceBucket? {
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
    
    private func dynamicGradientColor(for bucket: PriceBucket) -> Color {
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
    
    private func findBucket(for date: Date, in buckets: [PriceBucket]) -> PriceBucket? {
        buckets.first { $0.start <= date && $0.end > date }
    }
    
    private func isBucketSelected(_ bucket: PriceBucket, selectedDate: Date?) -> Bool {
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
                GlassEffectContainer(spacing: 14) {
                    VStack(spacing: 14) {
                        // Weekly Summary with glass effect and update button
                        MenuBarSummaryView(viewModel: summaryViewModel, spotPriceViewModel: viewModel)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        
                        // Chart section
                        chartSection
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        // Quick stats
                        quickStats
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 340, height: 620)
        .font(.custom("Avenir", size: 13))
    }
    
    private var menuHeader: some View {
        HStack(spacing: 12) {
            // App icon and title
            HStack(spacing: 10) {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeat(.continuous))
                    }
                
                Text("Spotpris")
                    .font(.custom("Avenir", size: 16).weight(.bold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Close button with glass effect
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial)
                    .cornerRadius(999)
            }
          
            .buttonStyle(.plain)
            .help("Avsluta")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var chartSection: some View {
        VStack(spacing: 8) {
            if case .loaded(let payload) = viewModel.state {
                SpotPriceBarChart(dayData: payload.day, configuration: .menuBar)
            } else {
                loadingStateView
                    .frame(height: 180)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 12) {
            Group {
                if case .loading = viewModel.state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.0)
                        .tint(.orange)
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            
            Text(loadingStatusText)
                .font(.custom("Avenir", size: 14).weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }
    
    @ViewBuilder
    private var quickStats: some View {
        if case .loaded(let payload) = viewModel.state {
            VStack(spacing: 12) {
                // Stat cards in a more compact layout
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        statCard(
                            title: "Lägsta",
                            value: "\(Int(payload.day.minOre.rounded()))",
                            unit: "öre",
                            color: .green,
                            icon: "arrow.down.circle.fill"
                        )
                        
                        statCard(
                            title: "Högsta", 
                            value: "\(Int(payload.day.maxOre.rounded()))",
                            unit: "öre",
                            color: .red,
                            icon: "arrow.up.circle.fill"
                        )
                        
                        statCard(
                            title: "Snitt",
                            value: "\(Int(averagePrice(payload.day.buckets).rounded()))",
                            unit: "öre",
                            color: .blue,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                }
                
                // Cost calculation section (more compact)
                costCalculationSection(payload: payload)
            }
        }
    }
    
    private func statCard(title: String, value: String, unit: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.custom("Avenir", size: 16).weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
 
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func costCalculationSection(payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Kostnad med detta pris")
                    .font(.custom("Avenir", size: 14).weight(.semibold))
                    .foregroundStyle(.primary)
                
                // Show current price indicator
                if let currentPrice = getCurrentPrice(payload) {
                    Text("(\(Int(currentPrice.rounded())) öre/kWh)")
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)) {
                GlassEffectContainer {
                    costCard(
                        title: "Dusch (10 min)",
                        mainCost: calculateCost(kWh: 6.0, currentPrice: getCurrentPriceOrAverage(payload)),
                        description: "~6 kWh",
                        color: .blue
                    )
                    
                    costCard(
                        title: "Pizza i ugn",
                        mainCost: calculateCost(kWh: 1.1, currentPrice: getCurrentPriceOrAverage(payload)),
                        description: "~1,1 kWh",
                        color: .orange
                    )
                    
                    costCard(
                        title: "Värmepump/dag",
                        mainCost: calculateCost(kWh: 24.0, currentPrice: getCurrentPriceOrAverage(payload)),
                        description: "~24 kWh",
                        color: .red
                    )
                    
                    costCard(
                        title: "Ladda bilen",
                        mainCost: calculateCost(kWh: 45.0, currentPrice: getCurrentPriceOrAverage(payload)),
                        description: "~45 kWh",
                        color: .green
                    )
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func costCard(title: String, mainCost: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Avenir", size: 12).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(description)
                        .font(.custom("Avenir", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(mainCost)
                    .font(.custom("Avenir", size: 15).weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("kr")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
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
    
    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double? {
        let now = Date()
        if let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) {
            return currentBucket.orePerKWh
        }
        // If no current bucket found (e.g., data is for a different day), return nil
        return nil
    }
    
    private func getCurrentPriceOrAverage(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        return getCurrentPrice(payload) ?? averagePrice(payload.day.buckets)
    }
    
    
    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
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
                    .font(.custom("Avenir", size: 13).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.state.labelColor)
                
                if case .loaded = viewModel.state {
                    Text("öre")
                        .font(.custom("Avenir", size: 11).weight(.medium))
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

extension DayChartData {
    func upcomingBuckets(limit: Int) -> [PriceBucket] {
        let now = Date()
        let upcoming = buckets.filter { $0.start >= now }
        
        // If no upcoming buckets, return the last few buckets for display
        if upcoming.isEmpty {
            return Array(buckets.suffix(limit))
        }
        
        return Array(upcoming.prefix(limit))
    }
}

extension PriceCategory {
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
        VStack(alignment: .leading, spacing: 10) {
            // Header with modern styling
            HStack(spacing: 8) {
                Text("Marknadsläge")
                    .font(.custom("Avenir", size: 14).weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Compact update button
                Button(action: {
                    Task {
                        await spotPriceViewModel.load()
                        await viewModel.loadSummary()
                    }
                }) {
                    Group {
                        if spotPriceViewModel.state == .loading || viewModel.state.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .glassEffect(.regular.tint(.blue.opacity(0.2)), in: .circle)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(spotPriceViewModel.state == .loading || viewModel.state.isLoading)
            }
            
            // Content based on state
            contentView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            Text("Väntar på uppdatering")
                .font(.custom("Avenir", size: 11).weight(.medium))
                .foregroundStyle(.secondary)
            
        case .loadingURL, .fetchingReport, .summarizing:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.mini)
                        .tint(.blue)
                    
                    Text(loadingText(for: viewModel.state))
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                
                // Compact progress bar
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.quaternary)
                        .frame(height: 2)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.blue.gradient)
                                .frame(width: geometry.size.width * progressValue, height: 2)
                                .animation(.easeInOut(duration: 0.3), value: progressValue)
                        }
                }
                .frame(height: 2)
            }
            
        case .loaded(let summary, let url, let isPreviousMonth):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: isPreviousMonth ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isPreviousMonth ? .orange : .green)
                    
                    Text(isPreviousMonth ? "Föreg. månad" : "Uppdaterad")
                        .font(.custom("Avenir", size: 10).weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                Text(summary)
                    .font(.custom("Avenir", size: 11).weight(.medium))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("Läs hela rapporten")
                            .font(.custom("Avenir", size: 10).weight(.semibold))
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(.blue.opacity(0.1)), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            
        case .failed(let error):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                
                Text("Kunde inte hämta marknadsöversikten")
                    .font(.custom("Avenir", size: 11).weight(.medium))
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

struct RemoveWindowBorder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            if let window = view.window {
                // Ta bort ramen
                window.styleMask.remove(.titled)
                window.styleMask.insert(.borderless)
                
                // Gör fönstret transparent
                window.isOpaque = false
                window.backgroundColor = .clear
                
                // Behåll skuggan för djup
                window.hasShadow = true
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
