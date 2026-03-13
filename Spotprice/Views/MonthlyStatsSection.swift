//
//  MonthlyStatsSection.swift
//  Spotprice
//

import SwiftUI

struct MonthlyStatsSection: View {
    let consumption: ConsumptionData?
    let powerPeaks: [PowerPeak]
    let consumptionError: String?
    let isConfigured: Bool
    let averagePrice: Double?
    let preciseCost: PreciseMonthlyCost?
    let tariff: SimplifiedTariff?

    var body: some View {
        if let consumption {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Förbrukning \(consumption.monthName)")
                    .font(DS.Font.semibold(14))
                    .foregroundStyle(.primary)

                HStack(spacing: DS.Spacing.sm) {
                    ConsumptionStatCard(
                        title: "Förbrukning",
                        value: "\(Int(consumption.totalKWh.rounded()))",
                        unit: "kWh",
                        color: .secondary
                    )

                    if let preciseCost {
                        let spotCost = preciseCost.totalCostKr
                        let gridCost = calculateGridCost(kWh: preciseCost.totalKWh)
                        let fixedCost = tariff?.monthlyFixedFee ?? 0
                        let totalCost = spotCost + gridCost + fixedCost
                        
                        ConsumptionStatCard(
                            title: "Faktisk kostnad",
                            value: String(format: "%.0f", totalCost),
                            unit: "kr",
                            subtitle: tariff != nil ? "Spot: \(String(format: "%.0f", spotCost)) kr • Nät: \(String(format: "%.0f", gridCost + fixedCost)) kr" : nil,
                            color: .secondary
                        )
                    } else if let avgPrice = averagePrice {
                        let estimatedSpotCost = (avgPrice / 100.0) * consumption.totalKWh
                        let gridCost = calculateGridCost(kWh: consumption.totalKWh)
                        let fixedCost = tariff?.monthlyFixedFee ?? 0
                        let totalCost = estimatedSpotCost + gridCost + fixedCost
                        
                        ConsumptionStatCard(
                            title: "Uppskattad kostnad",
                            value: String(format: "%.0f", totalCost),
                            unit: "kr",
                            subtitle: tariff != nil ? "Spot: \(String(format: "%.0f", estimatedSpotCost)) kr • Nät: \(String(format: "%.0f", gridCost + fixedCost)) kr" : nil,
                            color: .secondary
                        )
                    }
                }

                // Power peaks (effekttoppar)
                TopConsumptionDaysCard(peaks: powerPeaks)
            }
        } else if !isConfigured {
            SettingsLink {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Konfigurera förbrukning")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                        Text("Lägg till dina uppgifter för att se månadsstatistik")
                            .font(DS.Font.micro)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.lg)
                .glassCard(cornerRadius: DS.Radius.lg, interactive: true)
            }
            .buttonStyle(.plain)
        } else if let error = consumptionError {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.warning)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Kunde inte hämta förbrukning")
                        .font(DS.Font.medium(12))
                        .foregroundStyle(.primary)
                    Text(error)
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }
    
    // MARK: - Helpers
    
    private func calculateGridCost(kWh: Double) -> Double {
        guard let tariff = tariff else { return 0 }
        return tariff.energyTariffPerKWh * kWh
    }
}
