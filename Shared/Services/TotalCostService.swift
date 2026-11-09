//
//  TotalCostService.swift
//  Spotprice
//
//  Centralized service for total cost calculations including all components
//

import Foundation

final class TotalCostService: Sendable {
    nonisolated static let shared = TotalCostService()

    private let gridTariffService: GridTariffService
    private let consumptionService: ConsumptionService

    nonisolated init(gridTariffService: GridTariffService = GridTariffService(),
         consumptionService: ConsumptionService = ConsumptionService()) {
        self.gridTariffService = gridTariffService
        self.consumptionService = consumptionService
    }

    /// Calculate total cost from the central cost profile.
    /// Nord Pool spot is excluding VAT. Markup, grid, tax, certificates and monthly
    /// fees in the profile are consumer-facing amounts including VAT. Contract
    /// prices (fast/rörligt) are also stored including VAT.
    nonisolated func calculateTotalCost(
        kWh: Double,
        spotPriceOre: Double,
        profile: CostProfile,
        hoursInPeriod: Double,
        powerPeakKW: Double = 0
    ) -> EnhancedCost {
        let retailEnergyExcludingVAT = retailEnergyExcludingVAT(
            kWh: kWh,
            spotPriceOre: spotPriceOre,
            profile: profile
        )
        let gridEnergyIncludingVAT = ((profile.gridTransferOrePerKWh ?? 0) / 100.0) * kWh
        let fixedFeeIncludingVAT = proratedMonthlyCost(profile.gridMonthlyFee ?? 0, hoursInPeriod: hoursInPeriod)
        let powerTariffIncludingVAT = calculateEffectTariffCost(
            profile.effectTariff,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod
        )
        let energyTaxIncludingVAT = (profile.energyTaxOrePerKWh / 100.0) * kWh
        let certificateFeeIncludingVAT = (profile.certificateFeeOrePerKWh / 100.0) * kWh
        let surchargeIncludingVAT = retailMarkupCost(kWh: kWh, profile: profile)
        let monthlyFeeIncludingVAT = proratedMonthlyCost(profile.retailerMonthlyFee, hoursInPeriod: hoursInPeriod)

        let cost = EnhancedCost.assembling(
            spotExcludingVAT: retailEnergyExcludingVAT,
            gridEnergyIncludingVAT: gridEnergyIncludingVAT,
            fixedFeeIncludingVAT: fixedFeeIncludingVAT,
            powerTariffIncludingVAT: powerTariffIncludingVAT,
            energyTaxIncludingVAT: energyTaxIncludingVAT,
            certificateFeeIncludingVAT: certificateFeeIncludingVAT,
            surchargeIncludingVAT: surchargeIncludingVAT,
            monthlyFeeIncludingVAT: monthlyFeeIncludingVAT,
            vatRate: profile.vatRate
        )
#if DEBUG
        _ = WorkedExampleGuard.isValid
#endif
        return cost
    }

    /// Calculate total price per kWh from the central cost profile, including VAT.
    nonisolated func calculatePricePerKWh(
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

    func dayTotalCostsPerKWh(from dayData: DayChartData, profile: CostProfile) -> [Double] {
        dayData.buckets.map { calculatePricePerKWh(spotPriceOre: $0.orePerKWh, profile: profile) }
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

    nonisolated private func proratedMonthlyCost(_ monthlyCostKr: Double, hoursInPeriod: Double) -> Double {
        let hoursInMonth = 730.0
        return (monthlyCostKr / hoursInMonth) * hoursInPeriod
    }

    nonisolated private func retailEnergyExcludingVAT(
        kWh: Double,
        spotPriceOre: Double,
        profile: CostProfile
    ) -> Double {
        switch profile.retailContractType {
        case .spotPriceMarkup:
            return (spotPriceOre / 100.0) * kWh
        case .variableMonthlyPrice, .fixedPrice:
            if let contractOre = profile.contractPriceOrePerKWh {
                return ElectricityCostMath.excludingVAT((contractOre / 100.0) * kWh, vatRate: profile.vatRate)
            }
            return (spotPriceOre / 100.0) * kWh
        }
    }

    nonisolated private func retailMarkupCost(kWh: Double, profile: CostProfile) -> Double {
        guard profile.retailContractType == .spotPriceMarkup else {
            return 0
        }
        return (profile.retailerMarkupOrePerKWh / 100.0) * kWh
    }

    nonisolated private func calculateEffectTariffCost(
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

    /// Consumer-facing monthly amount if the peak were billed. Nil when the setting is off, or rate/peak is missing.
    nonisolated func hypotheticalMonthlyEffectTariffCostKr(
        peakKW: Double,
        profile: CostProfile,
        include: Bool
    ) -> Double? {
        guard include, peakKW > 0, let tariff = profile.effectTariff, tariff.monthlyPricePerKW > 0 else {
            return nil
        }
        return tariff.monthlyPricePerKW * peakKW
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
        totalCostService: TotalCostService = .shared,
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

struct CostBreakdownComponent: Identifiable, Sendable {
    let label: String
    let value: Double
    let isMain: Bool

    var id: String { label }
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

        otherComponents.append(("Skatt på el", cost.energyTaxKr))

        if cost.certificateFeeKr > 0 {
            otherComponents.append(("Elcertifikat", cost.certificateFeeKr))
        }
        if cost.powerTariffCostKr > 0 {
            otherComponents.append((EffectTariffCopy.lineTitle, cost.powerTariffCostKr))
        }
        if cost.vatKr > 0 {
            otherComponents.append(("Moms", cost.vatKr))
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

// MARK: - kr/kWh breakdown

enum KilowattHourLineKind: String, Sendable {
    case retailEnergy
    case markup
    case gridTransfer
    case energyTax
    case certificates
    case monthlyFees
    case powerTariff
    case vat
}

struct KilowattHourLine: Identifiable, Sendable {
    let kind: KilowattHourLineKind
    let title: String
    let amountKrPerKWh: Double

    var id: String { kind.rawValue }

    var amountOrePerKWh: Double {
        amountKrPerKWh * 100
    }
}

struct KilowattHourBreakdown: Sendable {
    let lines: [KilowattHourLine]
    let totalKrPerKWh: Double
    let includesGrid: Bool
    let missingGridMessage: String?

    static func make(from cost: EnhancedCost, profile: CostProfile) -> KilowattHourBreakdown {
        var lines: [KilowattHourLine] = []
        let retailTitle = profile.retailContractType == .spotPriceMarkup
            ? "Spotpris"
            : profile.retailContractDisplayName

        appendLine(
            &lines,
            kind: .retailEnergy,
            title: retailTitle,
            amount: cost.spotCostKr
        )

        if profile.retailContractType == .spotPriceMarkup {
            appendLine(
                &lines,
                kind: .markup,
                title: "Påslag",
                amount: cost.providerSurchargeKr
            )
        }

        let includesGrid = profile.hasConfiguredGridCosts
        if includesGrid {
            appendLine(
                &lines,
                kind: .gridTransfer,
                title: "Överföring",
                amount: cost.gridEnergyCostKr
            )
        }

        appendLine(&lines, kind: .energyTax, title: "Skatt på el", amount: cost.energyTaxKr)
        appendLine(&lines, kind: .certificates, title: "Elcertifikat", amount: cost.certificateFeeKr)

        let monthlyShare = cost.fixedFeeCostKr + cost.providerMonthlyFeeKr
        appendLine(
            &lines,
            kind: .monthlyFees,
            title: "Andel av månadsavgifter",
            amount: monthlyShare
        )
        appendLine(&lines, kind: .powerTariff, title: EffectTariffCopy.lineTitle, amount: cost.powerTariffCostKr)
        appendLine(&lines, kind: .vat, title: "Moms", amount: cost.vatKr)

        let missingGridMessage = includesGrid
            ? nil
            : "Elnätsavgift ingår inte. Välj elnätsbolag under Inställningar."

        return KilowattHourBreakdown(
            lines: lines,
            totalKrPerKWh: cost.totalKr,
            includesGrid: includesGrid,
            missingGridMessage: missingGridMessage
        )
    }

    private static func appendLine(
        _ lines: inout [KilowattHourLine],
        kind: KilowattHourLineKind,
        title: String,
        amount: Double
    ) {
        guard amount > 0.0000001 else { return }
        lines.append(KilowattHourLine(kind: kind, title: title, amountKrPerKWh: amount))
    }
}

#if DEBUG
nonisolated private enum WorkedExampleGuard {
    static let isValid: Bool = {
        let profile = ElectricityCostMath.workedExampleSE3Jonkoping20A()
        let cost = EnhancedCost.assembling(
            spotExcludingVAT: ElectricityCostMath.workedExampleSpotOre / 100.0,
            gridEnergyIncludingVAT: (profile.gridTransferOrePerKWh ?? 0) / 100.0,
            fixedFeeIncludingVAT: (profile.gridMonthlyFee ?? 0) / 730.0,
            powerTariffIncludingVAT: 0,
            energyTaxIncludingVAT: profile.energyTaxOrePerKWh / 100.0,
            certificateFeeIncludingVAT: profile.certificateFeeOrePerKWh / 100.0,
            surchargeIncludingVAT: profile.retailerMarkupOrePerKWh / 100.0,
            monthlyFeeIncludingVAT: profile.retailerMonthlyFee / 730.0,
            vatRate: profile.vatRate
        )
        let delta = abs(cost.totalKr - ElectricityCostMath.workedExampleExpectedTotalKr)
        assert(delta < 1e-9, "VAT worked example drifted: got \(cost.totalKr)")
        return delta < 1e-9
    }()
}
#endif
