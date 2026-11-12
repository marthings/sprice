//
//  SpotpriceAppWidget.swift
//  SpotpriceAppWidgetExtension
//
//  Created by Martin Berggren on 2026-06-10.
//

import WidgetKit
import SwiftUI
import OSLog

// MARK: - Timeline Entry

struct SpotpriceAppWidgetEntry: TimelineEntry {
    let date: Date
    let totalCostPerKWh: Double?
    let priceCategory: PriceCategory
    let dayCosts: [Double]
    let currentIndex: Int?

    static var placeholder: SpotpriceAppWidgetEntry {
        let curve: [Double] = [1.8, 1.6, 1.5, 1.4, 1.5, 1.9, 2.6, 3.1, 2.9, 2.5,
                               2.3, 2.2, 2.4, 2.7, 3.3, 3.7, 3.1, 2.6, 2.2, 1.9]
        return SpotpriceAppWidgetEntry(
            date: Date(),
            totalCostPerKWh: 2.47,
            priceCategory: .medium,
            dayCosts: curve,
            currentIndex: 9
        )
    }

    static var error: SpotpriceAppWidgetEntry {
        SpotpriceAppWidgetEntry(
            date: Date(),
            totalCostPerKWh: nil,
            priceCategory: .medium,
            dayCosts: [],
            currentIndex: nil
        )
    }
}

// MARK: - Timeline Provider

struct SpotpriceAppWidgetProvider: TimelineProvider {
    let service = SpotPriceService()
    let totalCostService = TotalCostService.shared

    func placeholder(in context: Context) -> SpotpriceAppWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpotpriceAppWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entries = await loadEntries()
            completion(entries.first ?? .error)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotpriceAppWidgetEntry>) -> Void) {
        Task {
            let now = Date()
            let entries = await loadEntries(now: now)
            completion(Timeline(
                entries: entries.isEmpty ? [.error] : entries,
                policy: .after(WidgetTimelineSchedule.nextDayAheadRefresh(from: now))
            ))
        }
    }

    private func loadEntries(now: Date = Date()) async -> [SpotpriceAppWidgetEntry] {
        let costProfile = await MainActor.run { ConsumptionSettings.shared.costProfile }
        let calendar = Calendar.energyHistory
        guard let today = await service.cachedOrFetchedDayChart(for: now, area: costProfile.priceArea) else {
            AppLog.widget.error("iOS widget: no day chart data")
            return [.error]
        }

        var tomorrow: DayChartData?
        if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            tomorrow = await service.cachedOrFetchedDayChart(for: tomorrowDate, area: costProfile.priceArea)
        }

        let remaining = WidgetTimelineSchedule.remainingBuckets(today: today, tomorrow: tomorrow, now: now)
        guard !remaining.isEmpty else {
            return [entry(at: now, day: today, profile: costProfile) ?? .error]
        }

        return remaining.compactMap { item in
            entry(at: item.date, day: item.day, profile: costProfile)
        }
    }

    private func entry(at date: Date, day: DayChartData, profile: CostProfile) -> SpotpriceAppWidgetEntry? {
        let dayCosts = totalCostService.dayTotalCostsPerKWh(from: day, profile: profile)
        guard let currentBucketIndex = day.currentBucketIndex(at: date),
              dayCosts.indices.contains(currentBucketIndex) else {
            return nil
        }

        let totalCost = dayCosts[currentBucketIndex]
        return SpotpriceAppWidgetEntry(
            date: date,
            totalCostPerKWh: totalCost,
            priceCategory: DS.Color.categoryForPrice(
                totalCost,
                min: dayCosts.min() ?? 0,
                max: dayCosts.max() ?? 0
            ),
            dayCosts: dayCosts,
            currentIndex: currentBucketIndex
        )
    }
}

// MARK: - Widget View

struct SpotpriceAppWidgetView: View {
    let entry: SpotpriceAppWidgetEntry
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetFamily) private var family

    private var chartHeight: CGFloat {
        switch family {
        case .systemMedium: return 48
        case .systemLarge: return 96
        default: return 32
        }
    }

    private var priceFontSize: CGFloat {
        switch family {
        case .systemMedium: return 48
        case .systemLarge: return 64
        default: return 40
        }
    }

    private var priceColor: Color {
        DS.Color.textForCategory(entry.priceCategory)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if let totalCost = entry.totalCostPerKWh {
                Text(totalCost, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.fixed(priceFontSize))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(renderingMode == .accented ? .primary : priceColor)
                Text("kr/kWh")
                    .font(DS.Font.unit)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                Text("--")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.secondary)
            }

            Spacer(minLength: 0)

            if entry.dayCosts.count > 1 {
                WidgetDayChart(costs: entry.dayCosts, currentIndex: entry.currentIndex)
                    .frame(height: chartHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct SpotpriceAppWidget: Widget {
    let kind: String = WidgetKind.iOSApp

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotpriceAppWidgetProvider()) { entry in
            SpotpriceAppWidgetView(entry: entry)
        }
        .configurationDisplayName("Spotpris")
        .description("Vad en kWh kostar nu och hur priset rör sig i dag.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    SpotpriceAppWidget()
} timeline: {
    SpotpriceAppWidgetEntry.placeholder
}