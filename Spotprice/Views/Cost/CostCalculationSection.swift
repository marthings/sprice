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

            KilowattHourBreakdownView(
                breakdown: KilowattHourBreakdown.make(
                    from: TotalCostService().calculateTotalCost(
                        kWh: 1,
                        spotPriceOre: currentPrice,
                        profile: profile,
                        hoursInPeriod: 1
                    ),
                    profile: profile
                ),
                style: .compact
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                ForEach(HouseholdCostExample.catalog) { example in
                    CostCardView(
                        title: example.title,
                        costBreakdown: CostCardView.calculateCost(
                            kWh: example.kWh,
                            priceInOre: currentPrice,
                            profile: profile,
                            hoursInPeriod: example.hoursInPeriod
                        ),
                        description: example.subtitle,
                        color: color(for: example.id),
                        retailEnergyLabel: profile.retailContractDisplayName
                    )
                }
            }

            Text(HouseholdCostExample.catalogFootnote)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)

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

    private func color(for exampleId: String) -> Color {
        switch exampleId {
        case "shower":
            return .blue
        case "oven":
            return DS.Color.warning
        case "dishwasher":
            return DS.Color.info
        case "laundry":
            return .purple
        case "heat-pump":
            return DS.Color.danger
        case "ev-charge":
            return DS.Color.success
        default:
            return DS.Color.secondary
        }
    }
}
