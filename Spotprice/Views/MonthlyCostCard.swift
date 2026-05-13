//
//  MonthlyCostCard.swift
//  Spotprice
//
//  Displays monthly cost with full breakdown
//

import SwiftUI

struct MonthlyCostCard: View {
    let title: String
    let enhancedCost: EnhancedCost
    let kWh: Double
    var showProviderWarning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header with title
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
            
            // Total cost - primary focus
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(enhancedCost.totalKr, format: .number.precision(.fractionLength(0)))
                    .font(DS.Font.bold(28).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("kr")
                    .font(DS.Font.medium(14))
                    .foregroundStyle(.secondary)
            }
            
            // Consumption info
            if kWh > 0 {
                Text("\(Int(kWh.rounded())) kWh • \((enhancedCost.totalKr / kWh).formatted(.number.precision(.fractionLength(2)))) kr/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.tertiary)
            }
            
            // Warning when no provider/DSO configured
            if showProviderWarning {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text("Konfigurera elbolag och nätägare i inställningar för bättre uppskattningar")
                        .font(DS.Font.micro)
                        .foregroundStyle(.blue)
                }
                .padding(.top, DS.Spacing.xxs)
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Nätavgifter och fasta avgifter är uppskattade värden.")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .padding(.vertical, DS.Spacing.xs)
            
            // Full breakdown
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Nedbrytning")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, DS.Spacing.xxs)
                
                // Elhandel
                CostBreakdownRow(
                    label: "Elhandel",
                    amount: enhancedCost.providerTotalKr,
                    color: .blue
                )
                if enhancedCost.spotCostKr > 0 {
                    CostBreakdownSubRow(
                        label: "Spotpris",
                        amount: enhancedCost.spotCostKr
                    )
                }
                if enhancedCost.providerSurchargeKr > 0 {
                    CostBreakdownSubRow(
                        label: "Påslag",
                        amount: enhancedCost.providerSurchargeKr
                    )
                }
                if enhancedCost.providerMonthlyFeeKr > 0 {
                    CostBreakdownSubRow(
                        label: "Månadsavgift",
                        amount: enhancedCost.providerMonthlyFeeKr
                    )
                }
                
                // Nät
                if enhancedCost.gridTotalKr > 0 {
                    CostBreakdownRow(
                        label: "Nät",
                        amount: enhancedCost.gridTotalKr,
                        color: .orange
                    )
                    if enhancedCost.gridEnergyCostKr > 0 {
                        CostBreakdownSubRow(
                            label: "Rörlig",
                            amount: enhancedCost.gridEnergyCostKr
                        )
                    }
                    if enhancedCost.fixedFeeCostKr > 0 {
                        CostBreakdownSubRow(
                            label: "Fast avgift",
                            amount: enhancedCost.fixedFeeCostKr
                        )
                    }
                    if enhancedCost.powerTariffCostKr > 0 {
                        CostBreakdownSubRow(
                            label: "Effekttariff",
                            amount: enhancedCost.powerTariffCostKr
                        )
                    }
                }
                
                // Skatter & avgifter
                if enhancedCost.taxesAndFeesKr > 0 {
                    CostBreakdownRow(
                        label: "Skatter & avgifter",
                        amount: enhancedCost.taxesAndFeesKr,
                        color: .green
                    )
                    if enhancedCost.energyTaxKr > 0 {
                        CostBreakdownSubRow(
                            label: "Energiskatt",
                            amount: enhancedCost.energyTaxKr
                        )
                    }
                    if enhancedCost.certificateFeeKr > 0 {
                        CostBreakdownSubRow(
                            label: "Elcertifikat",
                            amount: enhancedCost.certificateFeeKr
                        )
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}
