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
    let currentHour: Int

    static var placeholder: SpotPriceEntry {
        SpotPriceEntry(
            date: Date(),
            currentPrice: 42,
            priceCategory: .medium,
            dayData: nil,
            currentHour: 12
        )
    }

    static var error: SpotPriceEntry {
        SpotPriceEntry(
            date: Date(),
            currentPrice: nil,
            priceCategory: nil,
            dayData: nil,
            currentHour: Calendar.current.component(.hour, from: Date())
        )
    }
}

// MARK: - Timeline Provider

struct SpotPriceProvider: TimelineProvider {
    let service = SpotPriceService()

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

            let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let nextUpdate = Calendar.current.startOfHour(for: nextHour)

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchCurrentPrice() async -> SpotPriceEntry {
        do {
            let items = try await service.fetchSpotPrices(for: Date())
            let dayData = try service.makeDayChartData(from: items, for: Date())

            let now = Date()
            let currentHour = Calendar.current.component(.hour, from: now)

            if let currentBucket = dayData.buckets.first(where: { $0.start <= now && $0.end > now }) {
                return SpotPriceEntry(
                    date: now,
                    currentPrice: Int(currentBucket.orePerKWh.rounded()),
                    priceCategory: currentBucket.category,
                    dayData: dayData,
                    currentHour: currentHour
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

// MARK: - Mini Chart View

struct MiniPriceChart: View {
    let dayData: DayChartData
    let currentHour: Int

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
                // Area fill with gradient
                Path { path in
                    guard prices.count > 1 else { return }
                    let stepX = width / CGFloat(prices.count - 1)

                    path.move(to: CGPoint(x: 0, y: height))

                    for (index, price) in prices.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = (price - minPrice) / safeRange
                        let y = height - (normalizedY * height * 0.85) - (height * 0.075)

                        if index == 0 {
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Color.warning.opacity(0.4),
                            DS.Color.warning.opacity(0.1),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line with color segments
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
                .stroke(
                    LinearGradient(
                        colors: prices.map { priceToColor($0, min: minPrice, max: maxPrice) },
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                // Current time indicator
                if currentHour >= 0 && currentHour < 24 && prices.count > currentHour {
                    let stepX = width / CGFloat(max(prices.count - 1, 1))
                    let x = CGFloat(currentHour) * stepX
                    let price = prices[currentHour]
                    let normalizedY = (price - minPrice) / safeRange
                    let y = height - (normalizedY * height * 0.85) - (height * 0.075)

                    // Vertical line
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(DS.Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // Current point
                    Circle()
                        .fill(priceToColor(price, min: minPrice, max: maxPrice))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)

                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }
            }
        }
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
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let price = entry.currentPrice, let category = entry.priceCategory {
            VStack(spacing: 0) {
                // Header with price
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Nu")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)

                        PriceDisplay(price: price, category: category, size: .small)
                    }

                    Spacer()

                    PriceIcon(category: category, size: 16)
                }
                .padding(.bottom, DS.Spacing.sm)

                // Chart
                if let dayData = entry.dayData {
                    MiniPriceChart(dayData: dayData, currentHour: entry.currentHour)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }

                // Footer with time range
                HStack {
                    Text("00")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                    Spacer()
                    Text("12")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                    Spacer()
                    Text("24")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(DS.Spacing.md)
        } else {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DS.Color.secondary)
                Text("--")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget Configuration

struct SpotpriceWidget: Widget {
    let kind: String = "SpotpriceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotPriceProvider()) { entry in
            if #available(macOS 14.0, *) {
                SpotpriceWidgetEntryView(entry: entry)
                    .containerBackground(.ultraThinMaterial, for: .widget)
            } else {
                SpotpriceWidgetEntryView(entry: entry)
                    .padding()
                    .background(.ultraThinMaterial)
            }
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
