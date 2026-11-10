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
            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                Text("Kostnad med detta pris")
                    .font(DS.Font.semibold(14))
                    .foregroundStyle(.primary)

                if let price = getCurrentPrice(payload) {
                    let totalCostService = TotalCostService.shared
                    let totalCost = totalCostService.calculatePricePerKWh(spotPriceOre: price, profile: profile)
                    Text("(\(totalCost.formatted(.number.precision(.fractionLength(2)))) kr/kWh)")
                        .font(DS.Font.medium(11))
                        .foregroundStyle(DS.Color.secondary)
                }

                SectionInfoButton(
                    title: "Kostnad med detta pris",
                    paragraphs: costInfoParagraphs
                )
                Spacer(minLength: 0)
            }

            KilowattHourBreakdownView(
                breakdown: KilowattHourBreakdown.make(
                    from: TotalCostService.shared.calculateTotalCost(
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

        }
        .padding(.top, DS.Spacing.xs)
    }

    private var costInfoParagraphs: [String] {
        var parts = [
            "Här ser du vad en kilowattimme kostar just nu, och ungefär vad vanliga saker kostar till det priset.",
            "Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar.",
            HouseholdCostExample.catalogFootnote
        ]
        if let basisText = profile.retailContractCostBasisText {
            parts.append(basisText)
        }
        if profile.gridMonthlyFee != nil || profile.gridTransferOrePerKWh != nil {
            parts.append("Elnätskostnaden baseras på dina elnätsuppgifter och kan avvika från fakturan.")
        }
        return parts
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
