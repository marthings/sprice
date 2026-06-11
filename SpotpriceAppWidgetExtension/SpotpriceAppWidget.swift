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
    let priceColor: Color
    let dayCosts: [Double]      // Total cost per bucket over the day (kr/kWh)
    let currentIndex: Int?      // Index of the current bucket in dayCosts

    static var placeholder: SpotpriceAppWidgetEntry {
        let curve: [Double] = [1.8, 1.6, 1.5, 1.4, 1.5, 1.9, 2.6, 3.1, 2.9, 2.5,
                               2.3, 2.2, 2.4, 2.7, 3.3, 3.7, 3.1, 2.6, 2.2, 1.9]
        return SpotpriceAppWidgetEntry(date: Date(), totalCostPerKWh: 2.47, priceColor: DS.Color.warning, dayCosts: curve, currentIndex: 9)
    }

    static var error: SpotpriceAppWidgetEntry {
        SpotpriceAppWidgetEntry(date: Date(), totalCostPerKWh: nil, priceColor: DS.Color.warning, dayCosts: [], currentIndex: nil)
    }
}

// MARK: - Timeline Provider

struct SpotpriceAppWidgetProvider: TimelineProvider {
    let service = SpotPriceService()
    let totalCostService = TotalCostService()

    private let sharedDefaults = UserDefaults(suiteName: "group.mb.Spotprice") ?? .standard

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

            // Update at the next quarter hour
            let now = Date()
            let minute = Calendar.current.component(.minute, from: now)
            let minutesToNextQuarter = 15 - (minute % 15)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: minutesToNextQuarter, to: now) ?? now.addingTimeInterval(15 * 60)

            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchCurrentCost() async -> SpotpriceAppWidgetEntry {
        do {
            let now = Date()
            sharedDefaults.synchronize()

            let costProfile = await MainActor.run { ConsumptionSettings.shared.costProfile }

            let items = try await service.fetchSpotPrices(for: now, area: costProfile.priceArea)
            let dayData = try service.makeDayChartData(from: items, for: now)

            let currentBucketIndex = dayData.buckets.firstIndex(where: { $0.start <= now && $0.end > now })
                ?? dayData.buckets.indices.filter({ dayData.buckets[$0].end <= now }).last
                ?? dayData.buckets.indices.first

            guard let currentBucketIndex else {
                AppLog.widget.error("iOS widget: no valid bucket in dayData with \(dayData.buckets.count) buckets")
                return .error
            }

            let dayCosts = dayData.buckets.map {
                totalCostService.calculatePricePerKWh(spotPriceOre: $0.orePerKWh, profile: costProfile)
            }
            let totalCost = dayCosts[currentBucketIndex]

            // Color the price relative to today's range of total costs
            let color = DS.Color.forPrice(
                totalCost * 100,
                min: (dayCosts.min() ?? 0) * 100,
                max: (dayCosts.max() ?? 0) * 100
            )

            return SpotpriceAppWidgetEntry(
                date: now,
                totalCostPerKWh: totalCost,
                priceColor: color,
                dayCosts: dayCosts,
                currentIndex: currentBucketIndex
            )
        } catch {
            AppLog.widget.error("iOS widget: error fetching price: \(error.localizedDescription, privacy: .public)")
            return .error
        }
    }
}

// MARK: - Mini Day Chart

/// Minimal line chart over today's total cost with a vertical "now" marker.
/// The line is colored along its length by price level (green/yellow/red).
struct MiniDayChart: View {
    let costs: [Double]
    let currentIndex: Int?
    @Environment(\.widgetRenderingMode) var renderingMode

    private var lineGradient: LinearGradient {
        let minCost = costs.min() ?? 0
        let maxCost = costs.max() ?? 1
        switch renderingMode {
        case .accented:
            return LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(
                colors: costs.map { DS.Color.forPrice($0, min: minCost, max: maxCost) },
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let minCost = costs.min() ?? 0
            let maxCost = costs.max() ?? 1
            let range = maxCost - minCost
            let safeRange = range > 0 ? range : 1

            ZStack {
                areaPath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .fill(LinearGradient(
                        colors: [DS.Color.secondary.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))

                linePath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .stroke(lineGradient, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let currentIndex, costs.count > 1, costs.indices.contains(currentIndex) {
                    let x = CGFloat(currentIndex) / CGFloat(costs.count - 1) * width
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(DS.Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
        }
    }

    private func yPosition(for cost: Double, height: CGFloat, minCost: Double, safeRange: Double) -> CGFloat {
        let normalized = (cost - minCost) / safeRange
        return height - (normalized * height * 0.85) - (height * 0.075)
    }

    private func linePath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            for (index, cost) in costs.enumerated() {
                let point = CGPoint(x: CGFloat(index) * stepX,
                                    y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange))
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func areaPath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            path.move(to: CGPoint(x: 0, y: height))
            for (index, cost) in costs.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(index) * stepX,
                                         y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)))
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }
}

// MARK: - Widget View

struct SpotpriceAppWidgetView: View {
    var entry: SpotpriceAppWidgetProvider.Entry
    @Environment(\.widgetRenderingMode) var renderingMode
    @Environment(\.widgetFamily) var family

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

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if let totalCost = entry.totalCostPerKWh {
                Text(totalCost, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(priceFontSize))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(renderingMode == .accented ? .primary : entry.priceColor)
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
                MiniDayChart(costs: entry.dayCosts, currentIndex: entry.currentIndex)
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
