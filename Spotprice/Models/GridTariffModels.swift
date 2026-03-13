//
//  GridTariffModels.swift
//  Spotprice
//
//  Grid tariff data models for Eltariff API integration
//

import Foundation

// MARK: - API Response Models

struct TariffsResponse: Decodable, Sendable {
    let tariffs: [Tariff]
    let calendarPatterns: [CalendarPattern]
}

struct Tariff: Identifiable, Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let validPeriod: DateInterval
    let timeZone: String
    let lastUpdated: Date
    let companyName: String
    let companyOrgNo: String
    let product: String
    let direction: String
    let billingPeriod: String
    let fixedPrice: FixedPrice
    let energyPrice: EnergyPrice
    let powerPrice: PowerPrice
}

struct FixedPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [FixedPriceComponent]
}

struct FixedPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price
    let pricedPeriod: String
}

struct EnergyPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [EnergyPriceComponent]
}

struct EnergyPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price?
    let unit: String
    let spotPriceSettings: SpotPriceSettings?
    let recurringPeriods: [RecurringPeriod]?
}

struct PowerPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [PowerPriceComponent]
}

struct PowerPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price?
    let unit: String
    let url: String?
}

struct Price: Decodable, Sendable {
    let priceExVat: Double
    let priceIncVat: Double
    let currency: String
}

struct SpotPriceSettings: Decodable, Sendable {
    let multiplier: Double
    let currency: String
}

struct RecurringPeriod: Decodable, Sendable {
    let reference: String
    let frequency: String
    let activePeriods: [ActivePeriod]
}

struct ActivePeriod: Decodable, Sendable {
    let fromIncluding: String
    let toExcluding: String
    let calendarPatternReferences: CalendarPatternReferences?
}

struct CalendarPatternReferences: Decodable, Sendable {
    let include: [String]?
    let exclude: [String]?
}

struct CalendarPattern: Decodable, Sendable {
    let reference: String
    let frequency: String
    let days: [Int]?
    let dates: [String]?
}

struct DateInterval: Decodable, Sendable {
    let fromIncluding: String
    let toExcluding: String?
}

// MARK: - Simplified User-Facing Models

/// Simplified tariff for cost calculations
struct SimplifiedTariff: Sendable, Codable {
    let dsoName: String
    let dsoOrgNo: String
    let monthlyFixedFee: Double        // SEK incl. VAT
    let energyTariffPerKWh: Double     // SEK incl. VAT
    let powerTariffPerKW: Double?      // SEK incl. VAT per month
    let validFrom: Date
    let validTo: Date?
}

/// DSO metadata for picker
struct DSOOption: Identifiable, Sendable {
    let id: String         // companyOrgNo
    let name: String       // companyName
    let tariffId: UUID     // for fetching specific tariff
}

// MARK: - Enhanced Cost Models

struct EnhancedCost: Sendable {
    let spotCostKr: Double
    let gridEnergyCostKr: Double
    let fixedFeeCostKr: Double
    let powerTariffCostKr: Double

    var totalKr: Double {
        spotCostKr + gridEnergyCostKr + fixedFeeCostKr + powerTariffCostKr
    }
}
