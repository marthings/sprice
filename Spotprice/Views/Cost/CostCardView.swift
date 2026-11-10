//
//  CostCardView.swift
//  Spotprice
//

import SwiftUI

struct CostCardView: View {
    let title: String
    let costBreakdown: CostBreakdown?
    let description: String
    let color: Color
    var retailEnergyLabel: String = "Elhandel"

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Font.footnote)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(description)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if let breakdown = costBreakdown {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(breakdown.formattedTotal)
                        .font(DS.Font.bold(15).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("kr")
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                }
                
                if breakdown.hasGridCosts {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(retailEnergyLabel): \(breakdown.spot.formatted(.number.precision(.fractionLength(2)))) kr")
                            .font(DS.Font.footnote)
                            .foregroundStyle(.tertiary)
                        Text("Nät uppsk.: \(breakdown.grid.formatted(.number.precision(.fractionLength(2)))) kr")
                            .font(DS.Font.footnote)
                            .foregroundStyle(.tertiary)
                        if breakdown.fixed > 0 {
                            Text("Övrigt: \(breakdown.fixed.formatted(.number.precision(.fractionLength(2)))) kr")
                                .font(DS.Font.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.card)
        .spriceCard(tone: .cost)
    }
}

// MARK: - Cost Calculation Helper

extension CostCardView {
    struct CostBreakdown {
        let spot: Double
        let grid: Double
        let fixed: Double
        let total: Double

        var formattedTotal: String {
            total.formatted(.number.precision(.fractionLength(2)))
        }

        var hasGridCosts: Bool {
            grid > 0 || fixed > 0
        }
    }

    static func calculateCost(
        kWh: Double,
        priceInOre: Double,
        profile: CostProfile,
        hoursInPeriod: Double = 1.0
    ) -> CostBreakdown {
        let service = TotalCostService.shared
        let enhancedCost = service.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: priceInOre,
            profile: profile,
            hoursInPeriod: hoursInPeriod
        )

        return CostBreakdown(
            spot: enhancedCost.spotCostKr,
            grid: enhancedCost.gridTotalKr,
            fixed: enhancedCost.taxesAndFeesKr + enhancedCost.providerSurchargeKr + enhancedCost.providerMonthlyFeeKr + enhancedCost.vatKr,
            total: enhancedCost.totalKr
        )
    }

    static func calculateCost(
        kWh: Double,
        priceInOre: Double,
        tariff: SimplifiedTariff?,
        hoursInPeriod: Double = 1.0
    ) -> CostBreakdown {
        let service = TotalCostService.shared
        let settings = ConsumptionSettings.shared
        let enhancedCost = service.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: priceInOre,
            tariff: tariff,
            providerSurcharge: settings.effectiveSurchargePerKWh,
            providerMonthlyFee: settings.effectiveMonthlyFee,
            hoursInPeriod: hoursInPeriod
        )
        
        // Return breakdown with grouped costs
        return CostBreakdown(
            spot: enhancedCost.spotCostKr,
            grid: enhancedCost.gridTotalKr,
            fixed: enhancedCost.taxesAndFeesKr + enhancedCost.providerSurchargeKr + enhancedCost.providerMonthlyFeeKr + enhancedCost.vatKr,
            total: enhancedCost.totalKr
        )
    }
}
