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
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                CurrentCostHero(
                    payload: payload,
                    monthlyConsumption: monthlyConsumption,
                    preciseMonthlyCost: preciseMonthlyCost
                )
                MonthDailyCostSection(
                    priceArea: ConsumptionSettings.shared.costProfile.priceArea,
                    profile: ConsumptionSettings.shared.costProfile,
                    hasProvider: !ConsumptionSettings.shared.selectedProviderId.isEmpty
                )
                CostExamplesSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CurrentCostHero: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let monthlyConsumption: ConsumptionData?
    let preciseMonthlyCost: PreciseMonthlyCost?

    private let totalCostService = TotalCostService.shared
    private let monthlyCostEstimator = MonthlyCostEstimator()

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
        let totalPrice = totalCostService.calculatePricePerKWh(spotPriceOre: spotPrice, profile: profile)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)
        let forecast = monthlyForecast(spotPrice: spotPrice, profile: profile)

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                PriceLevelBadge(category: category)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(totalPrice, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.bold(64).monospacedDigit())
                        .foregroundStyle(DS.Color.forCategory(category))
                    Text("kr/kWh")
                        .font(DS.Font.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            if let forecast {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Prognos")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(AppFormatters.wholeNumber(forecast))
                            .font(DS.Font.title.monospacedDigit())
                        Text("kr/mån")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Prognos för månaden")
                .accessibilityValue("\(AppFormatters.wholeNumber(forecast)) kr/mån")
            }

            KilowattHourBreakdownView(
                breakdown: KilowattHourBreakdown.make(
                    from: totalCostService.calculateTotalCost(
                        kWh: 1,
                        spotPriceOre: spotPrice,
                        profile: profile,
                        hoursInPeriod: 1
                    ),
                    profile: profile
                )
            )
        }
    }

    private func monthlyForecast(spotPrice: Double, profile: CostProfile) -> Double? {
        guard let monthlyConsumption else { return nil }

        return monthlyCostEstimator.forecastMonthTotal(
            consumptionKWh: preciseMonthlyCost?.totalKWh ?? monthlyConsumption.totalKWh,
            spotPriceOre: forecastSpotPrice(fallbackSpotPrice: spotPrice),
            profile: profile
        )
    }

    private func forecastSpotPrice(fallbackSpotPrice: Double) -> Double {
        guard let preciseMonthlyCost,
              preciseMonthlyCost.totalKWh > 0 else {
            return fallbackSpotPrice
        }

        return (preciseMonthlyCost.totalCostKr / preciseMonthlyCost.totalKWh) * 100
    }

}
