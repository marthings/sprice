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
    let totalCostService = TotalCostService()

    func placeholder(in context: Context) -> SpotpriceAppWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpotpriceAppWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            completion(await fetchCurrentCost())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotpriceAppWidgetEntry>) -> Void) {
        Task {
            let entry = await fetchCurrentCost()
            completion(Timeline(
                entries: [entry],
                policy: .after(WidgetTimelineSchedule.nextQuarterHourUpdate(from: entry.date))
            ))
        }
    }

    private func fetchCurrentCost() async -> SpotpriceAppWidgetEntry {
        do {
            let now = Date()
            let costProfile = await MainActor.run { ConsumptionSettings.shared.costProfile }

            let items = try await service.fetchSpotPrices(for: now, area: costProfile.priceArea)
            let dayData = try service.makeDayChartData(from: items, for: now)
            // dayTotalCostsPerKWh uses calculatePricePerKWh, which includes VAT.
            let dayCosts = totalCostService.dayTotalCostsPerKWh(from: dayData, profile: costProfile)

            guard let currentBucketIndex = dayData.currentBucketIndex(at: now),
                  dayCosts.indices.contains(currentBucketIndex) else {
                AppLog.widget.error("iOS widget: no valid bucket in dayData with \(dayData.buckets.count) buckets")
                return .error
            }

            let totalCost = dayCosts[currentBucketIndex]
            let category = DS.Color.categoryForPrice(
                totalCost,
                min: dayCosts.min() ?? 0,
                max: dayCosts.max() ?? 0
            )

            return SpotpriceAppWidgetEntry(
                date: now,
                totalCostPerKWh: totalCost,
                priceCategory: category,
                dayCosts: dayCosts,
                currentIndex: currentBucketIndex
            )
        } catch {
            AppLog.widget.error("iOS widget: error fetching price: \(error.localizedDescription, privacy: .public)")
            return .error
        }
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
        DS.Color.forCategory(entry.priceCategory)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if let totalCost = entry.totalCostPerKWh {
                Text(totalCost, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(priceFontSize))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(renderingMode == .accented ? .primary : priceColor)
                Text("kr/kWh")
                    .font(DS.Font.micro)
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
    let kind: String = "SpotpriceAppWidgetV2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotpriceAppWidgetProvider()) { entry in
            SpotpriceAppWidgetView(entry: entry)
        }
        .configurationDisplayName("Spotpris")
        .description("Visar aktuell kostnad per kWh och dagens prisutveckling.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    SpotpriceAppWidget()
} timeline: {
    SpotpriceAppWidgetEntry.placeholder
}