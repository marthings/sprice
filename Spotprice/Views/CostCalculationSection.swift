//
//  CostCalculationSection.swift
//  Spotprice
//

import SwiftUI

struct CostCalculationSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay

    var body: some View {
        let currentPrice = getCurrentPriceOrAverage(payload)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Text("Kostnad med detta pris")
                    .font(DS.Font.semibold(14))
                    .foregroundStyle(.primary)

                if let price = getCurrentPrice(payload) {
                    Text("(\(Int(price.rounded())) öre/kWh)")
                        .font(DS.Font.medium(11))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                CostCardView(
                    title: "Dusch (10 min)",
                    mainCost: CostCardView.calculateCost(kWh: 6.0, priceInOre: currentPrice),
                    description: "~6 kWh",
                    color: .blue
                )

                CostCardView(
                    title: "Pizza i ugn",
                    mainCost: CostCardView.calculateCost(kWh: 1.1, priceInOre: currentPrice),
                    description: "~1,1 kWh",
                    color: DS.Color.warning
                )

                CostCardView(
                    title: "Värmepump/dag",
                    mainCost: CostCardView.calculateCost(kWh: 24.0, priceInOre: currentPrice),
                    description: "~24 kWh",
                    color: DS.Color.danger
                )

                CostCardView(
                    title: "Ladda bilen",
                    mainCost: CostCardView.calculateCost(kWh: 45.0, priceInOre: currentPrice),
                    description: "~45 kWh",
                    color: DS.Color.success
                )
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Helpers

    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double? {
        let now = Date()
        return payload.day.buckets.first { $0.start <= now && $0.end > now }?.orePerKWh
    }

    private func getCurrentPriceOrAverage(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        getCurrentPrice(payload) ?? averagePrice(payload.day.buckets)
    }

    func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}
