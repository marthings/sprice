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
    let error: String?

    static var placeholder: SpotPriceEntry {
        SpotPriceEntry(date: Date(), currentPrice: 42, priceCategory: .medium, error: nil)
    }

    static var error: SpotPriceEntry {
        SpotPriceEntry(date: Date(), currentPrice: nil, priceCategory: nil, error: "Kunde inte hämta pris")
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

            // Refresh at the next hour
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
            if let currentBucket = dayData.buckets.first(where: { $0.start <= now && $0.end > now }) {
                return SpotPriceEntry(
                    date: now,
                    currentPrice: Int(currentBucket.orePerKWh.rounded()),
                    priceCategory: currentBucket.category,
                    error: nil
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

// MARK: - Widget View

struct SpotpriceWidgetEntryView: View {
    var entry: SpotPriceEntry

    var body: some View {
        if let price = entry.currentPrice, let category = entry.priceCategory {
            VStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(categoryColor(category))

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(price)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(categoryColor(category))
                    Text("öre")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("per kWh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "bolt.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("--")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func categoryColor(_ category: PriceCategory) -> Color {
        switch category {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
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
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SpotpriceWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Spotpris")
        .description("Visar aktuellt elpris")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    SpotpriceWidget()
} timeline: {
    SpotPriceEntry.placeholder
}
