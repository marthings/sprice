//
//  TotalCostService.swift
//  Spotprice
//
//  Centralized service for total cost calculations including all components
//

import Foundation

final class TotalCostService: Sendable {
    private let gridTariffService: GridTariffService

    init(gridTariffService: GridTariffService = GridTariffService()) {
        self.gridTariffService = gridTariffService
    }

    /// Calculate total cost for a given consumption
    func calculateTotalCost(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        gridTariffService.calculateEnhancedCost(
            kWh: kWh,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
    }

    /// Calculate total price per kWh (all components included)
    func calculatePricePerKWh(
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared
    ) -> Double {
        let cost = calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings,
            hoursInPeriod: 1.0
        )
        return cost.totalKr  // kr/kWh
    }
    
    /// Format total price per kWh for display
    func formattedPricePerKWh(
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared
    ) -> String {
        let priceKr = calculatePricePerKWh(
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings
        )
        return String(format: "%.2f", priceKr)
    }
}
