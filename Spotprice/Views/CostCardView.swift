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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Font.micro)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(description)
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
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
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
                
                if breakdown.hasGridCosts {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Elhandel: \(String(format: "%.2f", breakdown.spot)) kr")
                            .font(DS.Font.micro)
                            .foregroundStyle(.tertiary)
                        Text("Nät: \(String(format: "%.2f", breakdown.grid)) kr")
                            .font(DS.Font.micro)
                            .foregroundStyle(.tertiary)
                        if breakdown.fixed > 0 {
                            Text("Övrigt: \(String(format: "%.2f", breakdown.fixed)) kr")
                                .font(DS.Font.micro)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.lg)
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
            String(format: "%.2f", total)
        }

        var hasGridCosts: Bool {
            grid > 0 || fixed > 0
        }
    }

    static func calculateCost(
        kWh: Double,
        priceInOre: Double,
        tariff: SimplifiedTariff?,
        hoursInPeriod: Double = 1.0
    ) -> CostBreakdown {
        let service = TotalCostService()
        let enhancedCost = service.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: priceInOre,
            tariff: tariff,
            hoursInPeriod: hoursInPeriod
        )
        
        // Return breakdown with grouped costs
        return CostBreakdown(
            spot: enhancedCost.spotCostKr,
            grid: enhancedCost.gridTotalKr,
            fixed: enhancedCost.taxesAndFeesKr + enhancedCost.providerSurchargeKr + enhancedCost.providerMonthlyFeeKr,
            total: enhancedCost.totalKr
        )
    }
}
