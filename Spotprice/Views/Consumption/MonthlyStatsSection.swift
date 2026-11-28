//
//  MonthlyStatsSection.swift
//  Spotprice
//

import SwiftUI

struct MonthlyStatsSection: View {
    let consumption: ConsumptionData?
    let powerPeaks: [PowerPeak]
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
                        retailEnergyLabel: settings.costProfile.retailContractDisplayName,
                        hypotheticalEffectTariffKr: hypotheticalEffectTariffKr
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
                        retailEnergyLabel: settings.costProfile.retailContractDisplayName,
                        hypotheticalEffectTariffKr: hypotheticalEffectTariffKr
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
            .buttonStyle(SpriceCardPressButtonStyle())
        }
    }
    
    // MARK: - Helpers
    
    private var hypotheticalEffectTariffKr: Double? {
        TotalCostService.shared.hypotheticalMonthlyEffectTariffCostKr(
            peakKW: powerPeaks.first?.kW ?? 0,
            profile: settings.costProfile,
            include: settings.includeHypotheticalEffectTariff
        )
    }

    private func calculateTotalMonthCost(spotCostKr: Double, kWh: Double) -> EnhancedCost {
        let service = TotalCostService.shared
        // Calculate average spot price per kWh from total spot cost
        let avgSpotPriceOre = kWh > 0 ? (spotCostKr / kWh) * 100.0 : 0

        // Use full month hours for monthly fixed fees
        let cost = service.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: avgSpotPriceOre,
            profile: settings.costProfile,
            hoursInPeriod: 730  // Full month
        )
        // Days this month under an older agreement version keep that version's price.
        guard let adjustment = LiveMonthPricing.adjustment(
            priceArea: settings.costProfile.priceArea,
            current: settings.costProfile
        ) else {
            return cost
        }
        return cost.adding(adjustment)
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
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .spriceCard(tone: .history)
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
            return "\(parts.joined(separator: ", ")) sparat för månaden"
        }
        if let averagePrice = summary.averageSpotPriceOrePerKWh {
            return "Snitt spotpris \(AppFormatters.ore(averagePrice))/kWh sparat"
        }
        return "Historik sparad för månaden"
    }

}
