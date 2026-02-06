//
//  ConsumptionModels.swift
//  Spotprice
//
//  Shared models for consumption data across all providers
//

import Foundation

// MARK: - Consumption Data

struct ConsumptionData: Sendable {
    let totalKWh: Double
    let values: [ConsumptionValue]
    let meterName: String
    let meterId: String
    let monthDate: Date

    /// Formatted total for display (e.g., "142 kWh")
    var formattedTotal: String {
        "\(Int(totalKWh.rounded())) kWh"
    }

    /// Month name for display (e.g., "januari 2026")
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }
}

// MARK: - Consumption Value

struct ConsumptionValue: Sendable {
    let date: Date
    let kWh: Double
    let price: Double
}

// MARK: - Daily Consumption

struct DailyConsumption: Identifiable, Sendable {
    let date: Date
    let kWh: Double

    var id: Date { date }

    /// Day of month for display (e.g., "15 jan")
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Hourly Consumption

struct HourlyConsumption: Sendable {
    let date: Date       // hour start
    let kWh: Double      // = kW for 1h interval
}

// MARK: - Quarterly Consumption (15-min intervals)

struct QuarterlyConsumption: Identifiable, Sendable {
    let date: Date
    let kWh: Double
    var id: Date { date }
}

// MARK: - Power Peak

struct PowerPeak: Identifiable, Sendable {
    let date: Date       // the hour
    let kW: Double       // timmedeleffekt
    var id: Date { date }
}

// MARK: - Precise Monthly Cost

struct PreciseMonthlyCost: Sendable {
    let totalCostKr: Double
    let totalKWh: Double
    let matchedIntervals: Int
    let totalIntervals: Int
}

// MARK: - Monthly Comparison

/// Comparison data for current and previous month
struct MonthlyComparison: Sendable {
    let current: ConsumptionData
    let previous: ConsumptionData?
    let currentAvgPrice: Double  // öre/kWh
    let previousAvgPrice: Double?

    /// Price change percentage (positive = more expensive, negative = cheaper)
    var priceChangePercent: Double? {
        guard let prevPrice = previousAvgPrice, prevPrice > 0 else { return nil }
        return ((currentAvgPrice - prevPrice) / prevPrice) * 100
    }

    /// Current month name (e.g., "februari")
    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: current.monthDate)
    }

    /// Previous month name (e.g., "januari")
    var previousMonthName: String? {
        guard let prev = previous else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: prev.monthDate)
    }
}
