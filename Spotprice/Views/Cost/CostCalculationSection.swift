//
//  CostCalculationSection.swift
//  Spotprice
//

import SwiftUI

struct CostCalculationSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let profile: CostProfile

    var body: some View {
        let currentPrice = getCurrentPriceOrAverage(payload)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Text("Kostnad med detta pris")
                    .font(DS.Font.semibold(14))
                    .foregroundStyle(.primary)

                if let price = getCurrentPrice(payload) {
                    let totalCostService = TotalCostService()
                    let totalCost = totalCostService.calculatePricePerKWh(spotPriceOre: price, profile: profile)
                    Text("(\(totalCost.formatted(.number.precision(.fractionLength(2)))) kr/kWh)")
                        .font(DS.Font.medium(11))
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            if let basisText = profile.retailContractCostBasisText {
                Label(basisText, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                CostCardView(
                    title: "Dusch (10 min)",
                    costBreakdown: CostCardView.calculateCost(
                        kWh: 6.0,
                        priceInOre: currentPrice,
                        profile: profile,
                        hoursInPeriod: 1.0
                    ),
                    description: "~6 kWh",
                    color: .blue,
                    retailEnergyLabel: profile.retailContractDisplayName
                )

                CostCardView(
                    title: "Pizza i ugn",
                    costBreakdown: CostCardView.calculateCost(
                        kWh: 1.1,
                        priceInOre: currentPrice,
                        profile: profile,
                        hoursInPeriod: 0.5
                    ),
                    description: "~1,1 kWh",
                    color: DS.Color.warning,
                    retailEnergyLabel: profile.retailContractDisplayName
                )

                CostCardView(
                    title: "Värmepump/dag",
                    costBreakdown: CostCardView.calculateCost(
                        kWh: 24.0,
                        priceInOre: currentPrice,
                        profile: profile,
                        hoursInPeriod: 24.0
                    ),
                    description: "~24 kWh",
                    color: DS.Color.danger,
                    retailEnergyLabel: profile.retailContractDisplayName
                )

                CostCardView(
                    title: "Ladda bilen",
                    costBreakdown: CostCardView.calculateCost(
                        kWh: 45.0,
                        priceInOre: currentPrice,
                        profile: profile,
                        hoursInPeriod: 8.0
                    ),
                    description: "~45 kWh",
                    color: DS.Color.success,
                    retailEnergyLabel: profile.retailContractDisplayName
                )
            }

            if profile.gridMonthlyFee != nil || profile.gridTransferOrePerKWh != nil {
                Label("Elnätskostnaden baseras på dina elnätsuppgifter och kan avvika från fakturan.", systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Helpers

    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double? {
        let now = Date.now
        return payload.day.buckets.first { $0.start <= now && $0.end > now }?.orePerKWh
    }

    private func getCurrentPriceOrAverage(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        getCurrentPrice(payload) ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
    }
}
