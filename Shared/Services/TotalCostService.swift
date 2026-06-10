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

struct MonthlyCostEstimate: Sendable {
    let totalKr: Double
    let kWh: Double
    let monthDate: Date
}

struct MonthlyCostEstimator: Sendable {
    private let totalCostService: TotalCostService
    private let calendar: Calendar

    init(
        totalCostService: TotalCostService = TotalCostService(),
        calendar: Calendar = .energyHistory
    ) {
        self.totalCostService = totalCostService
        self.calendar = calendar
    }

    func widgetMonthEstimate(
        historySummary: WidgetHistorySummary?,
        cachedConsumption: ConsumptionData?,
        dayData: DayChartData,
        profile: CostProfile,
        now: Date
    ) -> MonthlyCostEstimate {
        let monthlyKWh = historySummary?.totalConsumptionKWh ?? cachedConsumption?.totalKWh ?? 0
        let monthDate = historySummary?.periodStart ?? cachedConsumption?.monthDate ?? now

        if let historyCost = historySummary?.totalCostSEK {
            return MonthlyCostEstimate(totalKr: historyCost, kWh: monthlyKWh, monthDate: monthDate)
        }

        guard monthlyKWh > 0 else {
            return MonthlyCostEstimate(totalKr: 0, kWh: monthlyKWh, monthDate: monthDate)
        }

        let avgPrice = averageSpotPrice(dayData.buckets)
        let energyCost = totalCostService.calculateTotalCost(
            kWh: monthlyKWh,
            spotPriceOre: avgPrice,
            profile: profile,
            hoursInPeriod: 1.0
        )
        let monthlyFees = profile.retailerMonthlyFee + (profile.gridMonthlyFee ?? 0)
        let monthlyCostKr = energyCost.totalKr + monthlyFees

        return MonthlyCostEstimate(totalKr: monthlyCostKr, kWh: monthlyKWh, monthDate: monthDate)
    }

    func forecastMonthTotal(
        consumptionKWh: Double,
        spotPriceOre: Double,
        profile: CostProfile,
        now: Date = Date()
    ) -> Double? {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return nil }

        let elapsedSeconds = max(now.timeIntervalSince(monthInterval.start), 1)
        let monthSeconds = monthInterval.end.timeIntervalSince(monthInterval.start)
        guard monthSeconds > 0 else { return nil }

        let elapsedRatio = min(max(elapsedSeconds / monthSeconds, 0), 1)
        let elapsedHours = elapsedSeconds / 3600
        let costToDate = totalCostService.calculateTotalCost(
            kWh: consumptionKWh,
            spotPriceOre: spotPriceOre,
            profile: profile,
            hoursInPeriod: elapsedHours
        )

        return costToDate.totalKr / elapsedRatio
    }

    func averageSpotPrice(_ buckets: [PriceBucket]) -> Double {
        PriceBucketAnalytics.averageSpotPrice(buckets)
    }
}

struct CostBreakdownComponent: Sendable {
    let label: String
    let value: Double
    let isMain: Bool
}

enum CostBreakdownPresenter {
    static func topComponents(for cost: EnhancedCost, profile: CostProfile) -> [CostBreakdownComponent] {
        var components: [CostBreakdownComponent] = [
            CostBreakdownComponent(
                label: profile.retailContractDisplayName,
                value: cost.spotCostKr,
                isMain: true
            )
        ]

        var otherComponents: [(label: String, value: Double)] = []

        if profile.retailContractType == .spotPriceMarkup && cost.providerSurchargeKr > 0 {
            otherComponents.append(("Elhandelsavgifter", cost.providerSurchargeKr))
        }
        if cost.providerMonthlyFeeKr > 0 {
            otherComponents.append(("Elhandel månadavgift", cost.providerMonthlyFeeKr))
        }
        if cost.gridEnergyCostKr > 0 {
            otherComponents.append(("Elnätsavgift", cost.gridEnergyCostKr))
        }
        if cost.fixedFeeCostKr > 0 {
            otherComponents.append(("Elnät månadavgift", cost.fixedFeeCostKr))
        }

        otherComponents.append(("Energiskatt", cost.energyTaxKr))

        if cost.certificateFeeKr > 0 {
            otherComponents.append(("Elcertifikat", cost.certificateFeeKr))
        }
        if cost.powerTariffCostKr > 0 {
            otherComponents.append(("Effektavgift", cost.powerTariffCostKr))
        }

        otherComponents.sort { $0.value > $1.value }

        for component in otherComponents.prefix(2) {
            components.append(CostBreakdownComponent(
                label: component.label,
                value: component.value,
                isMain: false
            ))
        }

        let remaining = otherComponents.dropFirst(2)
        if !remaining.isEmpty {
            components.append(CostBreakdownComponent(
                label: "Övrigt",
                value: remaining.reduce(0) { $0 + $1.value },
                isMain: false
            ))
        }

        return components
    }
}
