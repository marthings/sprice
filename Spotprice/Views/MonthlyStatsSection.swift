//
//  MonthlyStatsSection.swift
//  Spotprice
//

import SwiftUI

struct MonthlyStatsSection: View {
    let consumption: ConsumptionData?
    let dailyConsumption: [DailyConsumption]
    let consumptionError: String?
    let isConfigured: Bool
    let averagePrice: Double?

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
                        color: .secondary,
                        icon: "bolt.circle.fill"
                    )

                    if let avgPrice = averagePrice {
                        let estimatedCost = (avgPrice / 100.0) * consumption.totalKWh
                        ConsumptionStatCard(
                            title: "Uppskattad kostnad",
                            value: String(format: "%.0f", estimatedCost),
                            unit: "kr",
                            color: .secondary,
                            icon: "creditcard.fill"
                        )
                    }
                }

                // Top consumption days
                TopConsumptionDaysCard(dailyValues: dailyConsumption)
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
}
