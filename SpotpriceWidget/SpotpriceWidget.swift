//
//  SpotpriceWidget.swift
//  SpotpriceWidget
//
//  Created by Martin Berggren on 2026-01-31.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SpotPriceEntry: TimelineEntry {
    let date: Date
    let currentPrice: Int?
    let priceCategory: PriceCategory?
    let dayData: DayChartData?
    let currentBucketIndex: Int
    let monthlyKWh: Double
    let monthlyCostKr: Double
    let monthDate: Date

    /// Compact month label (e.g., "feb")
    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthDate)
    }

    static var placeholder: SpotPriceEntry {
        SpotPriceEntry(
            date: Date(),
            currentPrice: 42,
            priceCategory: .medium,
            dayData: nil,
            currentBucketIndex: 48,  // Noon = 12 * 4
            monthlyKWh: 873,
            monthlyCostKr: 829,
            monthDate: Date()
        )
    }

    static var error: SpotPriceEntry {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let bucketIndex = hour * 4 + minute / 15
        return SpotPriceEntry(
            date: now,
            currentPrice: nil,
            priceCategory: nil,
            dayData: nil,
            currentBucketIndex: bucketIndex,
            monthlyKWh: 0,
            monthlyCostKr: 0,
            monthDate: now
        )
    }
}

// MARK: - Timeline Provider

struct SpotPriceProvider: TimelineProvider {
    let service = SpotPriceService()
    let consumptionService = ConsumptionService()

    func placeholder(in context: Context) -> SpotPriceEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpotPriceEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        Task {
            let entry = await fetchCurrentPrice()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotPriceEntry>) -> Void) {
        Task {
            let entry = await fetchCurrentPrice()

            // Update every 15 minutes (quarter hour)
            let now = Date()
            let minute = Calendar.current.component(.minute, from: now)
            let minutesToNextQuarter = 15 - (minute % 15)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: minutesToNextQuarter, to: now)!

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchCurrentPrice() async -> SpotPriceEntry {
        do {
            let now = Date()
            let items = try await service.fetchSpotPrices(for: now)
            let dayData = try service.makeDayChartData(from: items, for: now)

            // Fetch consumption (don't fail if this errors)
            let consumption = try? await consumptionService.fetchCurrentMonthConsumption()
            let monthlyKWh = consumption?.totalKWh ?? 0
            let monthDate = consumption?.monthDate ?? now

            // Calculate estimated cost using average price
            let avgPrice = dayData.buckets.map { $0.orePerKWh }.reduce(0, +) / Double(dayData.buckets.count)
            let monthlyCostKr = (monthlyKWh * avgPrice) / 100.0

            // Calculate bucket index (0-95 for 15-minute intervals)
            let hour = Calendar.current.component(.hour, from: now)
            let minute = Calendar.current.component(.minute, from: now)
            let currentBucketIndex = hour * 4 + minute / 15

            if let currentBucket = dayData.buckets.first(where: { $0.start <= now && $0.end > now }) {
                return SpotPriceEntry(
                    date: now,
                    currentPrice: Int(currentBucket.orePerKWh.rounded()),
                    priceCategory: currentBucket.category,
                    dayData: dayData,
                    currentBucketIndex: currentBucketIndex,
                    monthlyKWh: monthlyKWh,
                    monthlyCostKr: monthlyCostKr,
                    monthDate: monthDate
                )
            }

            return .error
        } catch {
            return .error
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Mini Chart View (Adapts to rendering mode)

struct MiniPriceChart: View {
    let dayData: DayChartData
    let currentBucketIndex: Int
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let prices = dayData.buckets.map { $0.orePerKWh }
            let minPrice = dayData.minOre
            let maxPrice = dayData.maxOre
            let range = maxPrice - minPrice
            let safeRange = range > 0 ? range : 1

            ZStack {
                // Area fill
                areaPath(prices: prices, width: width, height: height, minPrice: minPrice, safeRange: safeRange)
                    .fill(areaGradient)

                // Line
                linePath(prices: prices, width: width, height: height, minPrice: minPrice, safeRange: safeRange)
                    .stroke(lineGradient(prices: prices, minPrice: minPrice, maxPrice: maxPrice),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Current time indicator
                if currentBucketIndex >= 0 && currentBucketIndex < prices.count {
                    currentTimeIndicator(prices: prices, width: width, height: height,
                                        minPrice: minPrice, maxPrice: maxPrice, safeRange: safeRange)
                }
            }
        }
    }

    // MARK: - Rendering Mode Adaptive Colors

    private var areaGradient: LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(
                colors: [.primary.opacity(0.3), .primary.opacity(0.1), .clear],
                startPoint: .top, endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [DS.Color.warning.opacity(0.4), DS.Color.warning.opacity(0.1), .clear],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private func lineGradient(prices: [Double], minPrice: Double, maxPrice: Double) -> LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(
                colors: prices.map { priceToColor($0, min: minPrice, max: maxPrice) },
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    // MARK: - Path Builders

    private func areaPath(prices: [Double], width: CGFloat, height: CGFloat, minPrice: Double, safeRange: Double) -> Path {
        Path { path in
            guard prices.count > 1 else { return }
            let stepX = width / CGFloat(prices.count - 1)

            path.move(to: CGPoint(x: 0, y: height))

            for (index, price) in prices.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = (price - minPrice) / safeRange
                let y = height - (normalizedY * height * 0.85) - (height * 0.075)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }

    private func linePath(prices: [Double], width: CGFloat, height: CGFloat, minPrice: Double, safeRange: Double) -> Path {
        Path { path in
            guard prices.count > 1 else { return }
            let stepX = width / CGFloat(prices.count - 1)

            for (index, price) in prices.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = (price - minPrice) / safeRange
                let y = height - (normalizedY * height * 0.85) - (height * 0.075)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(prices: [Double], width: CGFloat, height: CGFloat,
                                      minPrice: Double, maxPrice: Double, safeRange: Double) -> some View {
        let stepX = width / CGFloat(max(prices.count - 1, 1))
        let x = CGFloat(currentBucketIndex) * stepX
        let price = prices[currentBucketIndex]
        let normalizedY = (price - minPrice) / safeRange
        let y = height - (normalizedY * height * 0.85) - (height * 0.075)

        // Vertical dashed line
        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        .stroke(.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        // Current point - adapts to rendering mode
        Circle()
            .fill(renderingMode == .accented ? .primary : priceToColor(price, min: minPrice, max: maxPrice))
            .frame(width: 8, height: 8)
            .position(x: x, y: y)
            .widgetAccentable()

        Circle()
            .fill(.background)
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
    }

    private func priceToColor(_ price: Double, min: Double, max: Double) -> Color {
        let range = max - min
        guard range > 0 else { return DS.Color.warning }

        let normalized = (price - min) / range

        if normalized <= 0.33 {
            return DS.Color.success
        } else if normalized <= 0.66 {
            return DS.Color.warning
        } else {
            return DS.Color.error
        }
    }
}

// MARK: - Widget View

struct SpotpriceWidgetEntryView: View {
    var entry: SpotPriceEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    /// Color based on actual price at current bucket in the chart data
    private var currentPriceColor: Color {
        guard let dayData = entry.dayData else {
            return DS.Color.warning
        }
        // Use the actual price from the current bucket to match the chart
        let prices = dayData.buckets.map { $0.orePerKWh }
        guard entry.currentBucketIndex >= 0 && entry.currentBucketIndex < prices.count else {
            return DS.Color.warning
        }
        let priceAtCurrentBucket = prices[entry.currentBucketIndex]
        return DS.Color.forPrice(priceAtCurrentBucket, min: dayData.minOre, max: dayData.maxOre)
    }

    var body: some View {
        if let price = entry.currentPrice, let _ = entry.priceCategory {
            VStack(alignment: .leading, spacing: 0) {
                
                priceView(price: price)
                    .padding(.bottom, DS.Spacing.sm)

                // Chart
                if let dayData = entry.dayData {
                    MiniPriceChart(dayData: dayData, currentBucketIndex: entry.currentBucketIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }

                // Monthly stats with month label
                HStack(alignment: .top, spacing: DS.Spacing.xxs) {
                    

                    HStack(spacing: DS.Spacing.xxs) {
                        Text("\(Int(entry.monthlyKWh.rounded()))")
                            .font(DS.Font.semibold(10).monospacedDigit())
                        Text("kWh")
                            .font(DS.Font.micro)
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: DS.Spacing.xxs) {
                        Text("\(Int(entry.monthlyCostKr.rounded()))")
                            .font(DS.Font.semibold(10).monospacedDigit())
                        Text("kr")
                            .font(DS.Font.micro)
                    }
                    .foregroundStyle(.secondary)
                }
                .widgetAccentable()
            }
            .padding(DS.Spacing.md)
        } else {
            errorView
        }
    }

    /// Get price category for accessibility
    private var currentPriceCategory: PriceCategory? {
        guard let dayData = entry.dayData else { return entry.priceCategory }
        let prices = dayData.buckets.map { $0.orePerKWh }
        guard entry.currentBucketIndex >= 0 && entry.currentBucketIndex < prices.count else {
            return entry.priceCategory
        }
        let price = prices[entry.currentBucketIndex]
        return DS.Color.categoryForPrice(price, min: dayData.minOre, max: dayData.maxOre)
    }

    @ViewBuilder
    private func priceView(price: Int) -> some View {
        HStack(alignment: .center) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text("\(price)")
                    .font(DS.Font.bold(20))
                    .monospacedDigit()
                    .foregroundStyle(renderingMode == .accented ? .primary : currentPriceColor)
                Text("öre")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Accessible text label for price level
            if let category = currentPriceCategory, renderingMode != .accented {
                Text(category.label)
                    .font(DS.Font.semibold(9))
                    .foregroundStyle(currentPriceColor.opacity(0.8))
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: DS.Size.iconMedium))
                .foregroundStyle(.secondary)
            Text("--")
                .font(DS.Font.title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Configuration

struct SpotpriceWidget: Widget {
    let kind: String = "SpotpriceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotPriceProvider()) { entry in
            SpotpriceWidgetEntryView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Spotpris")
        .description("Visar aktuellt elpris med dagskurva")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    SpotpriceWidget()
} timeline: {
    SpotPriceEntry.placeholder
}
