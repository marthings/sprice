import SwiftUI

struct CostTabView: View {
    let state: SpotPriceViewModel.State
    let monthlyConsumption: ConsumptionData?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let powerPeaks: [PowerPeak]
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let message):
            DashboardErrorView(message: message, onRetry: onRetry)
        case .loaded(let payload):
            let settings = ConsumptionSettings.shared
            let profile = settings.costProfile
            let hypotheticalKr = TotalCostService.shared.hypotheticalMonthlyEffectTariffCostKr(
                peakKW: powerPeaks.first?.kW ?? 0,
                profile: profile,
                include: settings.includeHypotheticalEffectTariff
            )
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                CurrentCostHero(payload: payload)
                if settings.includeHypotheticalEffectTariff {
                    HypotheticalEffectTariffCard(
                        peak: powerPeaks.first,
                        amountKr: hypotheticalKr
                    )
                }
                MonthDailyCostSection(
                    priceArea: profile.priceArea,
                    profile: profile,
                    hasProvider: !settings.selectedProviderId.isEmpty,
                    forecastKr: CostTabForecast.monthTotal(
                        payload: payload,
                        monthlyConsumption: monthlyConsumption,
                        preciseMonthlyCost: preciseMonthlyCost,
                        profile: profile,
                        hypotheticalEffectTariffKr: hypotheticalKr
                    ),
                    hypotheticalEffectTariffKr: hypotheticalKr
                )
                CostExamplesSection(payload: payload, profile: profile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum CostTabForecast {
    static func monthTotal(
        payload: SpotPriceViewModel.CurrentAndDay,
        monthlyConsumption: ConsumptionData?,
        preciseMonthlyCost: PreciseMonthlyCost?,
        profile: CostProfile,
        hypotheticalEffectTariffKr: Double? = nil
    ) -> Double? {
        guard let monthlyConsumption else { return nil }

        let currentBucket = payload.day.currentBucket
        let fallbackSpot = currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
        let spotPriceOre: Double
        if let preciseMonthlyCost, preciseMonthlyCost.totalKWh > 0 {
            spotPriceOre = (preciseMonthlyCost.totalCostKr / preciseMonthlyCost.totalKWh) * 100
        } else {
            spotPriceOre = fallbackSpot
        }

        guard let forecast = MonthlyCostEstimator().forecastMonthTotal(
            consumptionKWh: preciseMonthlyCost?.totalKWh ?? monthlyConsumption.totalKWh,
            spotPriceOre: spotPriceOre,
            profile: profile
        ) else {
            return nil
        }
        return forecast + (hypotheticalEffectTariffKr ?? 0)
    }
}

private struct HypotheticalEffectTariffCard: View {
    let peak: PowerPeak?
    let amountKr: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(EffectTariffCopy.lineTitle)
                .font(DS.Font.headline)
            if let amountKr {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(AppFormatters.wholeNumber(amountKr))
                        .font(DS.Font.bold(28).monospacedDigit())
                    Text("kr")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                if let peak {
                    Text("Räknat på \(powerPhrase(peak.kW)) \(AppFormatters.powerPeakHourLabel(peak.date)).")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let peak {
                Text("Högsta timmen är \(powerPhrase(peak.kW)). \(EffectTariffCopy.missingRate)")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ingen effekttopp att räkna på än. \(EffectTariffCopy.explanation)")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .cost)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let amountKr {
            return "\(EffectTariffCopy.lineTitle), \(AppFormatters.wholeNumber(amountKr)) kronor"
        }
        if let peak {
            return "Högsta timmen \(powerPhrase(peak.kW))"
        }
        return EffectTariffCopy.lineTitle
    }

    private func powerPhrase(_ kW: Double) -> String {
        if kW < 1 {
            return "\(Int((kW * 1000).rounded())) W"
        }
        return "\(kW.formatted(.number.precision(.fractionLength(1)))) kW"
    }
}

private struct CurrentCostHero: View {
    let payload: SpotPriceViewModel.CurrentAndDay

    private let totalCostService = TotalCostService.shared

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)
        let nextTotal = nextTotalKrPerKWh(profile: profile)

        KilowattHourBreakdownView(
            breakdown: KilowattHourBreakdown.make(
                from: totalCostService.calculateTotalCost(
                    kWh: 1,
                    spotPriceOre: spotPrice,
                    profile: profile,
                    hoursInPeriod: 1
                ),
                profile: profile
            ),
            style: .regular,
            priceCategory: category,
            nextTotalKrPerKWh: nextTotal
        )
    }

    private func nextTotalKrPerKWh(profile: CostProfile) -> Double? {
        guard let currentBucket = payload.day.currentBucket,
              let nextBucket = payload.day.buckets.first(where: { $0.start >= currentBucket.end }) else {
            return nil
        }
        return totalCostService.calculatePricePerKWh(spotPriceOre: nextBucket.orePerKWh, profile: profile)
    }
}
