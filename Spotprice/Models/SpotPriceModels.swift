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
}

// MARK: - Thresholds

struct Thresholds: Equatable, Sendable {
    /// Tertile cutoffs in öre/kWh used for classification
    let lowUpper: Double   // <= this is low
    let mediumUpper: Double // <= this is medium, above is high
}

// MARK: - Price Bucket

struct PriceBucket: Identifiable, Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let orePerKWh: Double
    let category: PriceCategory

    init(start: Date, end: Date, orePerKWh: Double, category: PriceCategory, id: UUID = UUID()) {
        self.start = start
        self.end = end
        self.orePerKWh = orePerKWh
        self.category = category
        self.id = id
    }
}

// MARK: - Day Chart Data

struct DayChartData: Equatable, Sendable {
    let buckets: [PriceBucket]
    let thresholds: Thresholds
    let minOre: Double
    let maxOre: Double

    var currentBucket: PriceBucket? {
        let now = Date()
        return buckets.first { $0.start <= now && $0.end > now }
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
