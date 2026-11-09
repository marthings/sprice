//
//  ConsumptionModels.swift
//  Spotprice
//
//  Shared models for consumption data across all providers
//

import Foundation

// MARK: - Consumption Data

struct ConsumptionData: Equatable, Sendable, Codable {
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
        AppFormatters.monthAndYear(monthDate)
    }

    func restricting(toDayOfMonth throughDay: Int, calendar: Calendar) -> ConsumptionData {
        let sliced = values.filter {
            calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month)
                && SameDayMonthComparison.date($0.date, isOnOrBeforeDay: throughDay, calendar: calendar)
        }
        return ConsumptionData(
            totalKWh: sliced.reduce(0) { $0 + $1.kWh },
            values: sliced,
            meterName: meterName,
            meterId: meterId,
            monthDate: monthDate
        )
    }
}

// MARK: - Consumption Value

struct ConsumptionValue: Equatable, Sendable, Codable {
    let date: Date
    let kWh: Double
    let price: Double
}

// MARK: - Daily Consumption

struct DailyConsumption: Equatable, Identifiable, Sendable {
    let date: Date
    let kWh: Double

    var id: Date { date }

    /// Day of month for display (e.g., "15 jan")
    var dayLabel: String {
        AppFormatters.shortDayAndMonth(date)
    }
}

// MARK: - Hourly Consumption

nonisolated struct HourlyConsumption: Sendable {
    let date: Date       // hour start
    let kWh: Double      // = kW for 1h interval
}

// MARK: - Quarterly Consumption (15-min intervals)

nonisolated struct QuarterlyConsumption: Identifiable, Sendable {
    let date: Date
    let kWh: Double
    var id: Date { date }
}

// MARK: - Power Peak

struct PowerPeak: Equatable, Identifiable, Sendable {
    let date: Date       // the hour
    let kW: Double       // timmedeleffekt
    var id: Date { date }
}

// MARK: - Precise Monthly Cost

struct PreciseMonthlyCost: Equatable, Sendable {
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
        AppFormatters.monthName(current.monthDate)
    }

    /// Previous month name (e.g., "januari")
    var previousMonthName: String? {
        guard let prev = previous else { return nil }
        return AppFormatters.monthName(prev.monthDate)
    }
}
