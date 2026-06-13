//
//  SpotpriceWidget.swift
//  SpotpriceWidget
//
//  Created by Martin Berggren on 2026-01-31.
//

import WidgetKit
import SwiftUI
import OSLog

// MARK: - Timeline Entry

struct SpotPriceEntry: TimelineEntry {
    let date: Date
    let currentPriceOre: Int?
    let currentTotalCostPerKWh: Double?
    let priceCategory: PriceCategory?
    let dayCosts: [Double]
    let currentBucketIndex: Int?
    let monthlyKWh: Double
    let monthlyCostKr: Double
    let retailContractLabel: String?
    let historySummary: WidgetHistorySummary?

    static var placeholder: SpotPriceEntry {
        let curve: [Double] = Array(repeating: 2.4, count: 96)
        return SpotPriceEntry(
            date: Date(),
            currentPriceOre: 42,
            currentTotalCostPerKWh: 2.47,
            priceCategory: .medium,
            dayCosts: curve,
            currentBucketIndex: 48,
            monthlyKWh: 873,
            monthlyCostKr: 829,
            retailContractLabel: nil,
            historySummary: nil
        )
    }

    static var error: SpotPriceEntry {
        SpotPriceEntry(
            date: Date(),
            currentPriceOre: nil,
            currentTotalCostPerKWh: nil,
            priceCategory: nil,
            dayCosts: [],
            currentBucketIndex: nil,
            monthlyKWh: 0,
            monthlyCostKr: 0,
            retailContractLabel: nil,
            historySummary: nil
        )
    }
}

// MARK: - Timeline Provider

struct SpotPriceProvider: TimelineProvider {
    let service = SpotPriceService()
    let totalCostService = TotalCostService()
    let monthlyCostEstimator = MonthlyCostEstimator()

    func placeholder(in context: Context) -> SpotPriceEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpotPriceEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        Task {
            completion(await fetchCurrentPrice())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotPriceEntry>) -> Void) {
        Task {
            let entry = await fetchCurrentPrice()
            let timeline = Timeline(
                entries: [entry],
                policy: .after(WidgetTimelineSchedule.nextQuarterHourUpdate(from: entry.date))
            )
            completion(timeline)
        }
    }

    private func fetchCurrentPrice() async -> SpotPriceEntry {
        do {
            let now = Date()

            let (cachedConsumption, costProfile) = await MainActor.run {
                let settings = ConsumptionSettings.shared
                return (settings.cachedConsumption, settings.costProfile)
            }

            let items = try await service.fetchSpotPrices(for: now, area: costProfile.priceArea)
            let dayData = try service.makeDayChartData(from: items, for: now)
            let historySummary = WidgetHistorySummaryCache.summary(
                monthKey: EnergyHistoryKey.monthKey(for: now),
                priceArea: costProfile.priceArea
            )

            let monthlyEstimate = monthlyCostEstimator.widgetMonthEstimate(
                historySummary: historySummary,
                cachedConsumption: cachedConsumption,
                dayData: dayData,
                profile: costProfile,
                now: now
            )

            let dayCosts = totalCostService.dayTotalCostsPerKWh(from: dayData, profile: costProfile)

            guard let currentBucketIndex = dayData.currentBucketIndex(at: now),
                  dayCosts.indices.contains(currentBucketIndex) else {
                AppLog.widget.error("No valid bucket found in dayData with \(dayData.buckets.count) buckets")
                return .error
            }

            let currentBucket = dayData.buckets[currentBucketIndex]
            let currentTotalCost = dayCosts[currentBucketIndex]
            let retailContractLabel = costProfile.isSpotFollowingRetailContract
                ? nil
                : costProfile.retailContractDisplayName

            AppLog.widget.info("Widget loaded successfully with price: \(Int(currentBucket.orePerKWh.rounded())) öre/kWh")

            return SpotPriceEntry(
                date: now,
                currentPriceOre: Int(currentBucket.orePerKWh.rounded()),
                currentTotalCostPerKWh: currentTotalCost,
                priceCategory: currentBucket.category,
                dayCosts: dayCosts,
                currentBucketIndex: currentBucketIndex,
                monthlyKWh: monthlyEstimate.kWh,
                monthlyCostKr: monthlyEstimate.totalKr,
                retailContractLabel: retailContractLabel,
                historySummary: historySummary
            )
        } catch {
            AppLog.widget.error("Error fetching price: \(error.localizedDescription, privacy: .public)")
            return .error
        }
    }
}

// MARK: - Mini Chart View

struct MacWidgetDayChart: View {
    let costs: [Double]
    let currentIndex: Int?
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let minCost = costs.min() ?? 0
            let maxCost = costs.max() ?? 0
            let safeRange = max(maxCost - minCost, 1)

            ZStack {
                areaPath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .fill(areaGradient)

                linePath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .stroke(
                        lineGradient(minCost: minCost, maxCost: maxCost),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                if let currentIndex,
                   costs.count > 1,
                   costs.indices.contains(currentIndex) {
                    currentTimeIndicator(
                        width: width,
                        height: height,
                        index: currentIndex,
                        minCost: minCost,
                        maxCost: maxCost,
                        safeRange: safeRange
                    )
                }
            }
        }
    }

    private var areaGradient: LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(
                colors: [.primary.opacity(0.3), .primary.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [DS.Color.warning.opacity(0.4), DS.Color.warning.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func lineGradient(minCost: Double, maxCost: Double) -> LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(
                colors: costs.map { DS.Color.forPrice($0, min: minCost, max: maxCost) },
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func yPosition(for cost: Double, height: CGFloat, minCost: Double, safeRange: Double) -> CGFloat {
        let normalized = (cost - minCost) / safeRange
        return height - (normalized * height * 0.85) - (height * 0.075)
    }

    private func areaPath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            path.move(to: CGPoint(x: 0, y: height))
            for (index, cost) in costs.enumerated() {
                path.addLine(to: CGPoint(
                    x: CGFloat(index) * stepX,
                    y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)
                ))
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }

    private func linePath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            for (index, cost) in costs.enumerated() {
                let point = CGPoint(
                    x: CGFloat(index) * stepX,
                    y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(
        width: CGFloat,
        height: CGFloat,
        index: Int,
        minCost: Double,
        maxCost: Double,
        safeRange: Double
    ) -> some View {
        let stepX = width / CGFloat(max(costs.count - 1, 1))
        let x = CGFloat(index) * stepX
        let cost = costs[index]
        let y = yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)

        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        .stroke(.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        Circle()
            .fill(renderingMode == .accented ? .primary : DS.Color.forPrice(cost, min: minCost, max: maxCost))
            .frame(width: 8, height: 8)
            .position(x: x, y: y)
            .widgetAccentable()

        Circle()
            .fill(.background)
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
    }
}

// MARK: - Widget Sections

private struct SpotpriceWidgetMonthlyStatsRow: View {
    let monthlyKWh: Double
    let monthlyCostKr: Double
    let statusLabel: String?
    let isStale: Bool

    private var shouldShow: Bool {
        monthlyKWh > 0 || monthlyCostKr > 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.xxs) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Spacer()

            if shouldShow {
                HStack(spacing: DS.Spacing.xxs) {
                    Text("\(Int(monthlyKWh.rounded()))")
                        .font(DS.Font.semibold(11).monospacedDigit())
                    Text("kWh")
                        .font(DS.Font.regular(9))
                        .foregroundStyle(DS.Color.secondary)
                }

                HStack(spacing: DS.Spacing.xxs) {
                    Text("\(Int(monthlyCostKr.rounded()))")
                        .font(DS.Font.semibold(11).monospacedDigit())
                    Text("kr")
                        .font(DS.Font.regular(9))
                        .foregroundStyle(DS.Color.secondary)
                }

                if let statusLabel {
                    Text(statusLabel)
                        .font(DS.Font.regular(8))
                        .foregroundStyle(isStale ? DS.Color.warning : DS.Color.secondary)
                }
            }
        }
        .widgetAccentable()
    }
}

private struct SpotpriceWidgetPriceRow: View {
    let totalCostPerKWh: Double?
    let spotPriceOre: Int?
    let retailContractLabel: String?
    let priceCategory: PriceCategory?
    let dayCosts: [Double]
    let currentBucketIndex: Int?
    let renderingMode: WidgetRenderingMode

    private var currentPriceColor: Color {
        guard let currentBucketIndex,
              dayCosts.indices.contains(currentBucketIndex) else {
            return DS.Color.warning
        }
        return DS.Color.forPrice(
            dayCosts[currentBucketIndex],
            min: dayCosts.min() ?? 0,
            max: dayCosts.max() ?? 0
        )
    }

    var body: some View {
        HStack(alignment: .center) {
            if let totalCostPerKWh {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.bold(24))
                            .monospacedDigit()
                            .foregroundStyle(renderingMode == .accented ? .primary : currentPriceColor)
                        Text("kr")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                    if let retailContractLabel {
                        Text(retailContractLabel)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            } else if let spotPriceOre {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text("\(spotPriceOre)")
                        .font(DS.Font.bold(24))
                        .monospacedDigit()
                        .foregroundStyle(renderingMode == .accented ? .primary : currentPriceColor)
                    Text("öre")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Spacer()

            if let priceCategory, renderingMode != .accented {
                Text(priceCategory.label)
                    .font(DS.Font.semibold(9))
                    .foregroundStyle(currentPriceColor)
            }
        }
    }
}

// MARK: - Widget View

struct SpotpriceWidgetEntryView: View {
    let entry: SpotPriceEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var monthlyDataIsStale: Bool {
        guard let historySummary = entry.historySummary else { return false }
        return !historySummary.isCurrentMonth(at: entry.date)
    }

    private var monthlyStatusLabel: String? {
        guard let historySummary = entry.historySummary else { return nil }

        if monthlyDataIsStale {
            return "gammal"
        }

        switch historySummary.dataCoverage {
        case .priceOnly:
            return "pris"
        case .estimatedCost:
            return "uppsk"
        case .partialConsumption:
            return "delvis"
        case .measuredConsumption:
            return "mätt"
        }
    }

    var body: some View {
        if entry.currentPriceOre != nil, entry.priceCategory != nil {
            VStack(alignment: .leading, spacing: 8) {
                SpotpriceWidgetMonthlyStatsRow(
                    monthlyKWh: entry.monthlyKWh,
                    monthlyCostKr: entry.monthlyCostKr,
                    statusLabel: monthlyStatusLabel,
                    isStale: monthlyDataIsStale
                )

                SpotpriceWidgetPriceRow(
                    totalCostPerKWh: entry.currentTotalCostPerKWh,
                    spotPriceOre: entry.currentPriceOre,
                    retailContractLabel: entry.retailContractLabel,
                    priceCategory: entry.priceCategory,
                    dayCosts: entry.dayCosts,
                    currentBucketIndex: entry.currentBucketIndex,
                    renderingMode: renderingMode
                )
                .padding(.bottom, DS.Spacing.sm)

                if entry.dayCosts.count > 1 {
                    MacWidgetDayChart(costs: entry.dayCosts, currentIndex: entry.currentBucketIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    Text("Ingen data")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        } else {
            SpotpriceWidgetErrorView()
        }
    }
}

private struct SpotpriceWidgetErrorView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: DS.Size.iconMedium))
                .foregroundStyle(DS.Color.secondary)
            Text("--")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.secondary)
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
        .configurationDisplayName("Sprice")
        .description("Visar aktuellt kvartspris och uppskattad kostnad")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    SpotpriceWidget()
} timeline: {
    SpotPriceEntry.placeholder
}