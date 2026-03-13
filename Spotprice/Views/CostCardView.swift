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
                        Text("Spot: \(String(format: "%.2f", breakdown.spot)) kr")
                            .font(DS.Font.micro)
                            .foregroundStyle(.tertiary)
                        Text("Nät: \(String(format: "%.2f", breakdown.grid + breakdown.fixed)) kr")
                            .font(DS.Font.micro)
                            .foregroundStyle(.tertiary)
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
        let spotCostKr = (priceInOre / 100.0) * kWh

        guard let tariff = tariff else {
            return CostBreakdown(spot: spotCostKr, grid: 0, fixed: 0, total: spotCostKr)
        }

        let gridCostKr = tariff.energyTariffPerKWh * kWh

        // Pro-rate fixed fee for the time period
        let hoursInMonth: Double = 730
        let fixedCostKr = (tariff.monthlyFixedFee / hoursInMonth) * hoursInPeriod

        return CostBreakdown(
            spot: spotCostKr,
            grid: gridCostKr,
            fixed: fixedCostKr,
            total: spotCostKr + gridCostKr + fixedCostKr
        )
    }
}
