import SwiftUI

struct CostTabView: View {
    let state: SpotPriceViewModel.State
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let message):
            DashboardErrorView(message: message, onRetry: onRetry)
        case .loaded(let payload):
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                CurrentCostHero(payload: payload, trendPrices: state.trendPrices)
                CostExamplesSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CurrentCostHero: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let trendPrices: (current: Double, next: Double)?

    private let totalCostService = TotalCostService()

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? averagePrice(payload.day.buckets)
        let totalPrice = totalCostService.calculatePricePerKWh(spotPriceOre: spotPrice, profile: profile)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)

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
                metricInline(title: "Spotpris", value: payload.currentDisplay, unit: "öre")
                if let trendPrices {
                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: trendPrices.current, next: trendPrices.next)
                        metricInline(
                            title: "Nästa kvart",
                            value: Int(trendPrices.next.rounded()).formatted(),
                            unit: "öre"
                        )
                    }
                }
                Spacer(minLength: 0)
            }
        }
   
    }

    private func metricInline(title: String, value: String, unit: String) -> some View {
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
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}
