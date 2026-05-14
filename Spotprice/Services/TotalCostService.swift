//
//  TotalCostService.swift
//  Spotprice
//
//  Centralized service for total cost calculations including all components
//

import Foundation

final class TotalCostService: Sendable {
    private let gridTariffService: GridTariffService
    private let consumptionService: ConsumptionService

    init(gridTariffService: GridTariffService = GridTariffService(),
         consumptionService: ConsumptionService = ConsumptionService()) {
        self.gridTariffService = gridTariffService
        self.consumptionService = consumptionService
    }

    /// Calculate total cost from the central cost profile.
    /// Profile values are consumer-facing values including VAT, matching the existing cost model.
    func calculateTotalCost(
        kWh: Double,
        spotPriceOre: Double,
        profile: CostProfile,
        hoursInPeriod: Double,
        powerPeakKW: Double = 0
    ) -> EnhancedCost {
        let retailEnergyCostKr = (retailEnergyPriceOrePerKWh(spotPriceOre: spotPriceOre, profile: profile) / 100.0) * kWh
        let gridEnergyCostKr = ((profile.gridTransferOrePerKWh ?? 0) / 100.0) * kWh
        let fixedFeeCostKr = proratedMonthlyCost(profile.gridMonthlyFee ?? 0, hoursInPeriod: hoursInPeriod)
        let powerTariffCostKr = calculateEffectTariffCost(
            profile.effectTariff,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
        let energyTaxKr = (profile.energyTaxOrePerKWh / 100.0) * kWh
        let certificateFeeKr = (profile.certificateFeeOrePerKWh / 100.0) * kWh
        let providerSurchargeKr = retailMarkupCost(kWh: kWh, profile: profile)
        let providerMonthlyFeeKr = proratedMonthlyCost(profile.retailerMonthlyFee, hoursInPeriod: hoursInPeriod)

        return EnhancedCost(
            spotCostKr: retailEnergyCostKr,
            gridEnergyCostKr: gridEnergyCostKr,
            fixedFeeCostKr: fixedFeeCostKr,
            powerTariffCostKr: powerTariffCostKr,
            energyTaxKr: energyTaxKr,
            certificateFeeKr: certificateFeeKr,
            providerSurchargeKr: providerSurchargeKr,
            providerMonthlyFeeKr: providerMonthlyFeeKr
        )
    }

    /// Calculate total price per kWh from the central cost profile.
    func calculatePricePerKWh(
        spotPriceOre: Double,
        profile: CostProfile
    ) -> Double {
        calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: spotPriceOre,
            profile: profile,
            hoursInPeriod: 1.0
        ).totalKr
    }

    /// Calculate total cost for a given consumption.
    /// Pass `providerSurcharge` and `providerMonthlyFee` from `ConsumptionSettings`
    /// at the call site (use `effectiveSurchargePerKWh` / `effectiveMonthlyFee`).
    func calculateTotalCost(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        providerSurcharge: Double = 0,
        providerMonthlyFee: Double = 0,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        gridTariffService.calculateEnhancedCost(
            kWh: kWh,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            providerSurcharge: providerSurcharge,
            providerMonthlyFee: providerMonthlyFee,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
    }

    /// Calculate total price per kWh (all components included).
    /// Pass `providerSurcharge` and `providerMonthlyFee` from `ConsumptionSettings`
    /// at the call site (use `effectiveSurchargePerKWh` / `effectiveMonthlyFee`).
    func calculatePricePerKWh(
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        providerSurcharge: Double = 0,
        providerMonthlyFee: Double = 0
    ) -> Double {
        calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            providerSurcharge: providerSurcharge,
            providerMonthlyFee: providerMonthlyFee,
            hoursInPeriod: 1.0
        ).totalKr  // kr/kWh
    }

    private func proratedMonthlyCost(_ monthlyCostKr: Double, hoursInPeriod: Double) -> Double {
        let hoursInMonth = 730.0
        return (monthlyCostKr / hoursInMonth) * hoursInPeriod
    }

    private func retailEnergyPriceOrePerKWh(spotPriceOre: Double, profile: CostProfile) -> Double {
        switch profile.retailContractType {
        case .spotPriceMarkup:
            return spotPriceOre
        case .variableMonthlyPrice, .fixedPrice:
            return profile.contractPriceOrePerKWh ?? spotPriceOre
        }
    }

    private func retailMarkupCost(kWh: Double, profile: CostProfile) -> Double {
        guard profile.retailContractType == .spotPriceMarkup else {
            return 0
        }
        return (profile.retailerMarkupOrePerKWh / 100.0) * kWh
    }

    private func calculateEffectTariffCost(
        _ effectTariff: EffectTariff?,
        powerPeakKW: Double,
        hoursInPeriod: Double
    ) -> Double {
        guard let effectTariff, powerPeakKW > 0 else { return 0 }
        return proratedMonthlyCost(
            effectTariff.monthlyPricePerKW * powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
    }

    // MARK: - Provider-Enhanced Calculations (app only, @MainActor)

    /// Fetch current provider cost info from API.
    @MainActor
    func fetchProviderCosts(settings: ConsumptionSettings? = nil) async -> ProviderCostInfo? {
        let settings = settings ?? .shared
        guard !settings.selectedProviderId.isEmpty else { return nil }

        let credentials = settings.getCredentials(for: settings.selectedProviderId)

        guard let providerInstance = ProviderRegistry.shared.createProvider(
            identifier: settings.selectedProviderId,
            credentials: credentials
        ) else {
            return nil
        }

        guard let priceProvider = providerInstance as? PriceInfoProvider else {
            return nil
        }

        do {
            return try await priceProvider.fetchCurrentPriceInfo()
        } catch {
            return type(of: priceProvider).defaultCostInfo
        }
    }

    /// Calculate total cost using provider data if available, otherwise use settings.
    @MainActor
    func calculateTotalCostWithProvider(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        providerCost: ProviderCostInfo?,
        settings: ConsumptionSettings? = nil,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        let settings = settings ?? .shared
        let useProviderData = providerCost.map { cost in
            cost.isRealTime && Date.now.timeIntervalSince(cost.timestamp) < 900
        } ?? false

        let surcharge: Double
        let monthlyFee: Double

        if useProviderData, let providerCost {
            surcharge = providerCost.surchargePerKWh ?? settings.effectiveSurchargePerKWh
            monthlyFee = providerCost.monthlyFee ?? settings.effectiveMonthlyFee
        } else {
            surcharge = settings.effectiveSurchargePerKWh
            monthlyFee = settings.effectiveMonthlyFee
        }

        return gridTariffService.calculateEnhancedCost(
            kWh: kWh,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            providerSurcharge: surcharge,
            providerMonthlyFee: monthlyFee,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
    }
}
