import SwiftUI

struct CostTabView: View {
    let state: SpotPriceViewModel.State
    let monthlyConsumption: ConsumptionData?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let message):
            DashboardErrorView(message: message, onRetry: onRetry)
        case .loaded(let payload):
            let profile = ConsumptionSettings.shared.costProfile
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                CurrentCostHero(payload: payload)
                MonthDailyCostSection(
                    priceArea: profile.priceArea,
                    profile: profile,
                    hasProvider: !ConsumptionSettings.shared.selectedProviderId.isEmpty,
                    forecastKr: CostTabForecast.monthTotal(
                        payload: payload,
                        monthlyConsumption: monthlyConsumption,
                        preciseMonthlyCost: preciseMonthlyCost,
                        profile: profile
                    )
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
        profile: CostProfile
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

        return MonthlyCostEstimator().forecastMonthTotal(
            consumptionKWh: preciseMonthlyCost?.totalKWh ?? monthlyConsumption.totalKWh,
            spotPriceOre: spotPriceOre,
            profile: profile
        )
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
