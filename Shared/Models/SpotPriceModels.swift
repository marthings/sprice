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

enum WidgetTimelineSchedule {
    /// Next quarter-hour boundary for widget timeline refresh policy.
    static func nextQuarterHourUpdate(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let minutesToNextQuarter = 15 - (minute % 15)
        return calendar.date(byAdding: .minute, value: minutesToNextQuarter, to: date)
            ?? date.addingTimeInterval(15 * 60)
    }
}

// MARK: - Price Bucket Analytics

enum PriceBucketAnalytics {
    static func averageSpotPrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}

// MARK: - Spot Price Item (API Response)

struct SpotPriceItem: Decodable, Equatable, Sendable {
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
