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
    let totalCostService = TotalCostService.shared
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
            let entries = await loadEntries()
            completion(entries.first ?? .error)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotPriceEntry>) -> Void) {
        Task {
            let now = Date()
            let entries = await loadEntries(now: now)
            completion(Timeline(
                entries: entries.isEmpty ? [.error] : entries,
                policy: .after(WidgetTimelineSchedule.nextDayAheadRefresh(from: now))
            ))
        }
    }

    private func loadEntries(now: Date = Date()) async -> [SpotPriceEntry] {
        let (cachedConsumption, costProfile) = await MainActor.run {
            let settings = ConsumptionSettings.shared
            return (settings.cachedConsumption, settings.costProfile)
        }
        let calendar = Calendar.energyHistory
        guard let today = await service.cachedOrFetchedDayChart(for: now, area: costProfile.priceArea) else {
            AppLog.widget.error("No day chart data for widget timeline")
            return [.error]
        }

        var tomorrow: DayChartData?
        if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            tomorrow = await service.cachedOrFetchedDayChart(for: tomorrowDate, area: costProfile.priceArea)
        }

        let historySummary = WidgetHistorySummaryCache.summary(
            monthKey: EnergyHistoryKey.monthKey(for: now),
            priceArea: costProfile.priceArea
        )
        let monthlyEstimate = monthlyCostEstimator.widgetMonthEstimate(
            historySummary: historySummary,
            cachedConsumption: cachedConsumption,
            profile: costProfile,
            now: now
        )
        let remaining = WidgetTimelineSchedule.remainingBuckets(today: today, tomorrow: tomorrow, now: now)
        let slots = remaining.isEmpty
            ? [(date: now, day: today)]
            : remaining.map { (date: $0.date, day: $0.day) }

        return slots.compactMap { item in
            entry(
                at: item.date,
                day: item.day,
                profile: costProfile,
                monthlyEstimate: monthlyEstimate,
                historySummary: historySummary
            )
        }
    }

    private func entry(
        at date: Date,
        day: DayChartData,
        profile: CostProfile,
        monthlyEstimate: MonthlyCostEstimate,
        historySummary: WidgetHistorySummary?
    ) -> SpotPriceEntry? {
        let dayCosts = totalCostService.dayTotalCostsPerKWh(from: day, profile: profile)
        guard let currentBucketIndex = day.currentBucketIndex(at: date),
              dayCosts.indices.contains(currentBucketIndex) else {
            return nil
        }

        let currentBucket = day.buckets[currentBucketIndex]
        return SpotPriceEntry(
            date: date,
            currentPriceOre: Int(currentBucket.orePerKWh.rounded()),
            currentTotalCostPerKWh: dayCosts[currentBucketIndex],
            priceCategory: currentBucket.category,
            dayCosts: dayCosts,
            currentBucketIndex: currentBucketIndex,
            monthlyKWh: monthlyEstimate.kWh,
            monthlyCostKr: monthlyEstimate.totalKr,
            retailContractLabel: profile.isSpotFollowingRetailContract ? nil : profile.retailContractDisplayName,
            historySummary: historySummary
        )
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
                        .font(DS.Font.semibold(11))
                    Text("kWh")
                        .font(DS.Font.regular(9))
                        .foregroundStyle(DS.Color.secondary)
                }

                HStack(spacing: DS.Spacing.xxs) {
                    Text("\(Int(monthlyCostKr.rounded()))")
                        .font(DS.Font.semibold(11))
                    Text("kr")
                        .font(DS.Font.regular(9))
                        .foregroundStyle(DS.Color.secondary)
                }

            }
        }
        .padding()
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
            return DS.Color.warningText
        }
        return DS.Color.textForCategory(DS.Color.categoryForPrice(
            dayCosts[currentBucketIndex],
            min: dayCosts.min() ?? 0,
            max: dayCosts.max() ?? 0
        ))
    }

    var body: some View {
        HStack(alignment: .center) {
            if let totalCostPerKWh {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.black(24))
                            .foregroundStyle(renderingMode == .accented ? .primary : currentPriceColor)
                        Text("kr/kWh")
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                    if let retailContractLabel {
                        Text(retailContractLabel)
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                .padding(.horizontal)
            } else if let spotPriceOre {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(Double(spotPriceOre) / 100, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.black(24))
                        .foregroundStyle(renderingMode == .accented ? .primary : currentPriceColor)
                    Text("kr/kWh")
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                }
                .padding()
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
                    WidgetDayChart(costs: entry.dayCosts, currentIndex: entry.currentBucketIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    Text("Ingen data")
                        .font(DS.Font.footnote)
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
    let kind: String = WidgetKind.macOSMenuBar

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotPriceProvider()) { entry in
            SpotpriceWidgetEntryView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Sprice")
        .description("Visar aktuellt kvartspris och uppskattad kostnad")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    SpotpriceWidget()
} timeline: {
    SpotPriceEntry.placeholder
}
