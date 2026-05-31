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
                    Text(coverageTitle(historySummary))
                        .font(DS.Font.micro)
                        .foregroundStyle(coverageColor(historySummary))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(coverageColor(historySummary).opacity(0.12), in: .capsule)
                    Spacer()
                }

                historySummaryCard(historySummary)
            }
        } else if !isConfigured {
            SettingsLink {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(DS.Color.secondary)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Konfigurera förbrukning")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                        Text("Lägg till dina uppgifter för att se månadsstatistik")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondary)
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
                    if let providerName {
                        Text("Kunde inte hämta förbrukning från \(providerName)")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Kunde inte hämta förbrukning")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                    }
                    Text(error)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
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
                .foregroundStyle(coverageColor(summary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(historySummaryText(summary))
                    .font(DS.Font.medium(12))
                    .foregroundStyle(.primary)
                Text(coverageText(summary))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    private func historySummaryText(_ summary: HistoricalEnergySummaryValue) -> String {
        var parts: [String] = []

        if let cost = summary.totalCostSEK {
            parts.append("\(Int(cost.rounded()).formatted()) kr")
        }
        if let consumption = summary.totalConsumptionKWh {
            parts.append("\(consumption.formatted(.number.precision(.fractionLength(0...1)))) kWh")
        }
        if !parts.isEmpty {
            return "\(parts.joined(separator: " · ")) sparat för månaden"
        }
        if let averagePrice = summary.averageSpotPriceOrePerKWh {
            return "Snitt spotpris \(Int(averagePrice.rounded()).formatted()) öre/kWh sparat"
        }
        return "Historik sparad för månaden"
    }

    private func coverageTitle(_ summary: HistoricalEnergySummaryValue) -> String {
        switch summary.dataCoverage {
        case .priceOnly:
            return "Pris"
        case .estimatedCost:
            return "Uppskattat"
        case .partialConsumption:
            return "Delvis mätt"
        case .measuredConsumption:
            return "Mätt"
        }
    }

    private func coverageText(_ summary: HistoricalEnergySummaryValue) -> String {
        switch summary.dataCoverage {
        case .priceOnly:
            return "Förbrukningsdata saknas. Visar sparad prishistorik."
        case .estimatedCost:
            return "Förbrukningsdata saknas. Visar sparad uppskattad kostnad."
        case .partialConsumption:
            if let ratio = summary.measuredCoverageRatio {
                let percent = ratio.formatted(.percent.precision(.fractionLength(0)))
                return "Förbrukningsdata saknas. Historiken täcker \(percent) av intervallen."
            }
            return "Förbrukningsdata saknas. Visar delvis mätt historik."
        case .measuredConsumption:
            return "Förbrukningsdata saknas. Visar sparad mätt förbrukning."
        }
    }

    private func coverageColor(_ summary: HistoricalEnergySummaryValue) -> Color {
        switch summary.dataCoverage {
        case .priceOnly:
            return DS.Color.secondary
        case .estimatedCost:
            return DS.Color.warning
        case .partialConsumption:
            return DS.Color.info
        case .measuredConsumption:
            return DS.Color.success
        }
    }
}
