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
    let historySummary: HistoricalEnergySummaryValue?
    
    private var settings: ConsumptionSettings {
        ConsumptionSettings.shared
    }
    
    private var shouldShowPrecisionHint: Bool {
        settings.costProfile.confidence == .estimated
    }
    
    private var providerName: String? {
        guard !settings.selectedProviderId.isEmpty else { return nil }
        return ProviderRegistry.shared.metadata(for: settings.selectedProviderId)?.displayName
    }

    var body: some View {
        if let consumption {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Förbrukning \(consumption.monthName)")
                        .font(DS.Font.semibold(14))
                        .foregroundStyle(.primary)
                    
                    // Show provider name badge
                    if let providerName {
                        Text("·")
                            .font(DS.Font.semibold(12))
                            .foregroundStyle(DS.Color.secondary)
                        Text(providerName)
                            .font(DS.Font.medium(11))
                            .foregroundStyle(DS.Color.secondary)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(.quaternary.opacity(0.6), in: .capsule)
                    }
                    
                    Spacer()
                }

                // Main cost card with full breakdown
                if let preciseCost {
                    let enhancedCost = calculateTotalMonthCost(
                        spotCostKr: preciseCost.totalCostKr,
                        kWh: preciseCost.totalKWh
                    )
                    
                    MonthlyCostCard(
                        title: "Förbrukningsbaserad kostnad",
                        enhancedCost: enhancedCost,
                        kWh: preciseCost.totalKWh,
                        showPrecisionHint: shouldShowPrecisionHint,
                        costBasisNote: settings.costProfile.retailContractCostBasisText,
                        retailEnergyLabel: settings.costProfile.retailContractDisplayName
                    )
                } else if let avgPrice = averagePrice {
                    let estimatedSpotCost = (avgPrice / 100.0) * consumption.totalKWh
                    let enhancedCost = calculateTotalMonthCost(
                        spotCostKr: estimatedSpotCost,
                        kWh: consumption.totalKWh
                    )
                    
                    MonthlyCostCard(
                        title: "Uppskattad kostnad",
                        enhancedCost: enhancedCost,
                        kWh: consumption.totalKWh,
                        showPrecisionHint: shouldShowPrecisionHint,
                        costBasisNote: settings.costProfile.retailContractCostBasisText,
                        retailEnergyLabel: settings.costProfile.retailContractDisplayName
                    )
                }

                // Power peaks (effekttoppar)
                TopConsumptionDaysCard(peaks: powerPeaks)
            }
        } else if let historySummary {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Förbrukning från historik")
                        .font(DS.Font.semibold(14))
                        .foregroundStyle(.primary)
                    HistoryCoverageBadge(
                        coverage: historySummary.dataCoverage,
                        horizontalPadding: DS.Spacing.xs
                    )
                    Spacer()
                }

                historySummaryCard(historySummary)
            }
        } else if !isConfigured {
            SettingsLink {
                AppStatusCard(
                    icon: "gearshape.fill",
                    title: "Konfigurera förbrukning",
                    message: "Lägg till dina uppgifter för att se månadsstatistik",
                    color: DS.Color.secondary,
                    trailingIcon: "chevron.right",
                    interactive: true,
                    messageLineLimit: 2
                )
            }
            .buttonStyle(.plain)
        } else if let error = consumptionError {
            AppStatusRow(
                icon: "exclamationmark.triangle.fill",
                title: providerName.map { "Kunde inte hämta förbrukning från \($0)" } ?? "Kunde inte hämta förbrukning",
                message: error,
                color: DS.Color.warning,
                titleFont: DS.Font.medium(12),
                messageLineLimit: 2
            )
            .padding(DS.Spacing.md)
            .glassCard()
        }
    }
    
    // MARK: - Helpers
    
    private func calculateTotalMonthCost(spotCostKr: Double, kWh: Double) -> EnhancedCost {
        let service = TotalCostService()
        // Calculate average spot price per kWh from total spot cost
        let avgSpotPriceOre = kWh > 0 ? (spotCostKr / kWh) * 100.0 : 0

        // Use full month hours for monthly fixed fees
        return service.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: avgSpotPriceOre,
            profile: settings.costProfile,
            hoursInPeriod: 730  // Full month
        )
    }

    private func historySummaryCard(_ summary: HistoricalEnergySummaryValue) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(summary.dataCoverage.displayColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(historySummaryText(summary))
                    .font(DS.Font.medium(12))
                    .foregroundStyle(.primary)
                Text(summary.coverageText(style: .fallback))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .glassCard()
    }

    private func historySummaryText(_ summary: HistoricalEnergySummaryValue) -> String {
        var parts: [String] = []

        if let cost = summary.totalCostSEK {
            parts.append(AppFormatters.wholeKr(cost))
        }
        if let consumption = summary.totalConsumptionKWh {
            parts.append(AppFormatters.kWh(consumption))
        }
        if !parts.isEmpty {
            return "\(parts.joined(separator: " · ")) sparat för månaden"
        }
        if let averagePrice = summary.averageSpotPriceOrePerKWh {
            return "Snitt spotpris \(AppFormatters.ore(averagePrice))/kWh sparat"
        }
        return "Historik sparad för månaden"
    }

}
