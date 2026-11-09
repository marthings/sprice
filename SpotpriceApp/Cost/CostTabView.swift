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
                    trendPrices: state.trendPrices,
                    monthlyConsumption: monthlyConsumption,
                    preciseMonthlyCost: preciseMonthlyCost
                )
                CostExamplesSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CurrentCostHero: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let trendPrices: (current: Double, next: Double)?
    let monthlyConsumption: ConsumptionData?
    let preciseMonthlyCost: PreciseMonthlyCost?

    private let totalCostService = TotalCostService()
    private let monthlyCostEstimator = MonthlyCostEstimator()

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
        let totalPrice = totalCostService.calculatePricePerKWh(spotPriceOre: spotPrice, profile: profile)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)
        let forecast = monthlyForecast(spotPrice: spotPrice, profile: profile)

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
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
            }

            HStack(spacing: DS.Spacing.lg) {
                metricInline(title: "Spotpris", value: payload.currentDisplay, unit: "öre/kWh")
                Spacer()
                if let trendPrices {
                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: trendPrices.current, next: trendPrices.next)
                        metricInline(
                            title: "Nästa kvart",
                            value: AppFormatters.oreValue(trendPrices.next),
                            unit: "öre/kWh"
                        )
                    }
                }
                Spacer()

                if let forecast {
                    metricInline(
                        title: "Prognos",
                        value: AppFormatters.wholeNumber(forecast),
                        unit: "kr/mån",
                        accessibilityLabel: "Prognos för månaden"
                    )
                    .layoutPriority(1)
                }
                Spacer(minLength: 0)
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

    private func metricInline(
        title: String,
        value: String,
        unit: String,
        accessibilityLabel: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(DS.Font.title.monospacedDigit())
                Text(unit)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityValue("\(value) \(unit)")
    }

    private func formattedMetric(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
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
