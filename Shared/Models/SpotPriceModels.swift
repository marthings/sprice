//
//  SpotPriceModels.swift
//  Spotprice
//
//  Core data models for spot price functionality
//

import Foundation

// MARK: - Price Category

enum PriceCategory: String, Equatable, CaseIterable, Sendable {
    case low
    case medium
    case high

    /// Swedish label for accessibility
    var label: String {
        switch self {
        case .low: return "Lågt"
        case .medium: return "Medel"
        case .high: return "Högt"
        }
    }

    /// SF Symbol that works for colorblind users
    var accessibilityIcon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }

    /// Compact icon for tight spaces
    var compactIcon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }
}

// MARK: - Thresholds

struct Thresholds: Equatable, Sendable {
    /// Tertile cutoffs in öre/kWh used for classification
    let lowUpper: Double   // <= this is low
    let mediumUpper: Double // <= this is medium, above is high
}

// MARK: - Price Bucket

struct PriceBucket: Identifiable, Equatable, Sendable {
    let start: Date
    let end: Date
    let orePerKWh: Double
    let category: PriceCategory

    var id: Date { start }

    init(start: Date, end: Date, orePerKWh: Double, category: PriceCategory) {
        self.start = start
        self.end = end
        self.orePerKWh = orePerKWh
        self.category = category
    }
}

// MARK: - Day Chart Data

struct DayChartData: Equatable, Sendable {
    let buckets: [PriceBucket]
    let thresholds: Thresholds
    let minOre: Double
    let maxOre: Double

    var currentBucket: PriceBucket? {
        currentBucket(at: Date())
    }

    func currentBucket(at date: Date) -> PriceBucket? {
        buckets.first { $0.start <= date && $0.end > date }
    }

    func currentBucketIndex(at date: Date = Date()) -> Int? {
        if let index = buckets.firstIndex(where: { $0.start <= date && $0.end > date }) {
            return index
        }
        if let lastPastIndex = buckets.indices.filter({ buckets[$0].end <= date }).last {
            return lastPastIndex
        }
        return buckets.indices.first
    }
}

// MARK: - Widget Timeline

nonisolated enum WidgetTimelineSchedule {
    /// Next quarter-hour boundary for widget timeline refresh policy.
    static func nextQuarterHourUpdate(from date: Date = Date(), calendar: Calendar = .energyHistory) -> Date {
        let minute = calendar.component(.minute, from: date)
        let minutesToNextQuarter = 15 - (minute % 15)
        return calendar.date(byAdding: .minute, value: minutesToNextQuarter, to: date)
            ?? date.addingTimeInterval(15 * 60)
    }

    /// Tomorrow's day-ahead prices typically publish around 13:00 Europe/Stockholm.
    static func nextDayAheadRefresh(from date: Date = Date(), calendar: Calendar = .energyHistory) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 13
        components.minute = 15
        components.second = 0
        let todayPublication = calendar.date(from: components) ?? date
        if date < todayPublication {
            return todayPublication
        }
        return calendar.date(byAdding: .day, value: 1, to: todayPublication)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    static func remainingBuckets(
        today: DayChartData,
        tomorrow: DayChartData?,
        now: Date
    ) -> [(date: Date, bucket: PriceBucket, day: DayChartData)] {
        var result: [(Date, PriceBucket, DayChartData)] = []
        for bucket in today.buckets where bucket.end > now {
            result.append((max(bucket.start, now), bucket, today))
        }
        if let tomorrow {
            for bucket in tomorrow.buckets {
                result.append((bucket.start, bucket, tomorrow))
            }
        }
        if result.isEmpty, let current = today.currentBucket(at: now) {
            result.append((now, current, today))
        }
        return result
    }
}

nonisolated enum SpotPriceDayCache {
    private static let folderName = "SpotPriceCache"

    static func store(_ items: [SpotPriceItem], area: String, calendar: Calendar = .energyHistory) {
        guard !items.isEmpty else { return }

        let grouped = Dictionary(grouping: items) { item in
            EnergyHistoryKey.dayKey(for: item.timeStart, calendar: calendar)
        }

        for (dayKey, dayItems) in grouped {
            let payload = Payload(area: area, dayKey: dayKey, items: dayItems, savedAt: Date())
            guard let data = try? JSONEncoder().encode(payload),
                  let url = fileURL(area: area, dayKey: dayKey) else {
                continue
            }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    static func items(for day: Date, area: String, calendar: Calendar = .energyHistory) -> [SpotPriceItem]? {
        let dayKey = EnergyHistoryKey.dayKey(for: day, calendar: calendar)
        guard let url = fileURL(area: area, dayKey: dayKey),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.items.isEmpty else {
            return nil
        }
        return payload.items
    }

    static func lookup(for day: Date, area: String, calendar: Calendar = .energyHistory) -> [Date: Double]? {
        guard let items = items(for: day, area: area, calendar: calendar) else {
            return nil
        }
        var map: [Date: Double] = [:]
        map.reserveCapacity(items.count)
        for item in items {
            map[item.timeStart] = item.sekPerKWh * 100.0
        }
        return map
    }

    private static func fileURL(area: String, dayKey: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: EnergyHistoryConstants.appGroupIdentifier)?
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(area, isDirectory: true)
            .appendingPathComponent("\(dayKey).json", isDirectory: false)
    }

    private struct Payload: Codable, Sendable {
        let area: String
        let dayKey: String
        let items: [SpotPriceItem]
        let savedAt: Date
    }
}

// MARK: - Price Bucket Analytics

nonisolated enum SpotPriceMatching: Sendable {
    nonisolated static func price(
        for intervalStart: Date,
        hoursInPeriod: Double,
        lookup: [Date: Double],
        calendar: Calendar
    ) -> Double? {
        if hoursInPeriod >= 23 {
            let dayPrices = lookup.compactMap { start, ore -> Double? in
                calendar.isDate(start, inSameDayAs: intervalStart) ? ore : nil
            }
            return average(dayPrices)
        }

        if hoursInPeriod <= 0.4 {
            if let exact = lookup[intervalStart] {
                return exact
            }
            return hourAverage(for: intervalStart, lookup: lookup, calendar: calendar)
        }

        return hourAverage(for: intervalStart, lookup: lookup, calendar: calendar)
            ?? lookup[intervalStart]
    }

    nonisolated private static func hourAverage(
        for intervalStart: Date,
        lookup: [Date: Double],
        calendar: Calendar
    ) -> Double? {
        guard let hourStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour], from: intervalStart)
        ) else {
            return nil
        }

        var quarters: [Double] = []
        quarters.reserveCapacity(4)
        for offset in 0..<4 {
            guard let start = calendar.date(byAdding: .minute, value: offset * 15, to: hourStart) else {
                continue
            }
            if let ore = lookup[start] {
                quarters.append(ore)
            }
        }
        if let averaged = average(quarters) {
            return averaged
        }
        return lookup[hourStart]
    }

    nonisolated private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

enum PriceBucketAnalytics {
    static func averageSpotPrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}

// MARK: - Spot Price Item (API Response)

struct SpotPriceItem: Codable, Equatable, Sendable {
    let sekPerKWh: Double
    let eurPerKWh: Double
    let exr: Double
    let timeStart: Date
    let timeEnd: Date

    private enum CodingKeys: String, CodingKey {
        case sekPerKWh = "SEK_per_kWh"
        case eurPerKWh = "EUR_per_kWh"
        case exr = "EXR"
        case timeStart = "time_start"
        case timeEnd = "time_end"
    }
}

// MARK: - Displayable Error

struct DisplayableError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

extension Error {
    /// Prefer typed Swedish `LocalizedError` descriptions over raw `localizedDescription`.
    var userFacingMessage: String {
        if let localized = self as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return String(localized: "Ett oväntat fel inträffade. Försök igen senare.")
    }
}
