//
//  ModernMenuBarView.swift
//  Spotprice
//

import SwiftUI

struct ModernMenuBarView: View {
    var viewModel: SpotPriceViewModel

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Kostnad just nu").font(DS.Font.semibold(14))
                    chartSection
                        .glassCard(cornerRadius: DS.Radius.md)
                    quickStats
                    historicalSummary
                    MonthlyStatsSection(
                        consumption: viewModel.monthlyConsumption,
                        powerPeaks: viewModel.powerPeaks,
                        consumptionError: viewModel.consumptionError,
                        isConfigured: ConsumptionSettings.shared.isConfigured,
                        averagePrice: loadedAveragePrice,
                        preciseCost: viewModel.preciseMonthlyCost,
                        historySummary: viewModel.currentMonthHistorySummary
                    )
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: DS.Size.menuBarWidth, height: DS.Size.menuBarHeight)
        .font(DS.Font.callout)
    }

    @ViewBuilder
    private var historicalSummary: some View {
        if let summary = viewModel.currentMonthHistorySummary {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                    .foregroundStyle(coverageColor(summary))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Sparad månad")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                        Text(coverageTitle(summary))
                            .font(DS.Font.micro)
                            .foregroundStyle(coverageColor(summary))
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(coverageColor(summary).opacity(0.12), in: .capsule)
                    }
                    Text(historySummaryText(summary))
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }

    // MARK: - Header

    private var menuHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text("Sprice")
                    .font(DS.Font.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: DS.Size.closeButtonIconSize, weight: .semibold))
                        .frame(width: DS.Size.closeButtonSize, height: DS.Size.closeButtonSize)
                        .foregroundStyle(.primary)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Inställningar")
                .buttonStyle(.plain)
                .help("Inställningar")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Size.closeButtonIconSize, weight: .bold))
                        .frame(width: DS.Size.closeButtonSize, height: DS.Size.closeButtonSize)
                        .foregroundStyle(.primary)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Avsluta")
                .buttonStyle(.plain)
                .help("Avsluta")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            if case .loaded(let payload) = viewModel.state {
                SpotPriceBarChart(dayData: payload.day, configuration: .menuBar, tariff: viewModel.currentTariff)
            } else {
                loadingStateView
                    .frame(height: DS.Size.chartHeightMenuBar)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var loadingStateView: some View {
        VStack(spacing: DS.Spacing.md) {
            Group {
                if case .loading = viewModel.state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.0)
                        .tint(.orange)
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: DS.Size.iconXL, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }

            Text(loadingStatusText)
                .font(DS.Font.medium(14))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Quick Stats

    @ViewBuilder
    private var quickStats: some View {
        if case .loaded(let payload) = viewModel.state {
            VStack(spacing: DS.Spacing.md) {
                SharedPriceRangeSection(
                    dayData: payload.day,
                    profile: ConsumptionSettings.shared.costProfile,
                    style: .compact
                )
                CostCalculationSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            }
        }
    }

    // MARK: - Helpers

    private var loadedAveragePrice: Double? {
        guard case .loaded(let payload) = viewModel.state else { return nil }
        return averagePrice(payload.day.buckets)
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }

    private var loadingStatusText: String {
        switch viewModel.state {
        case .idle:
            return "Tryck Uppdatera för att ladda dagens kvartspriser"
        case .loading:
            return "Hämtar aktuella kvartspriser..."
        case .failed(let message):
            return message
        case .loaded:
            return ""
        }
    }

    private func historySummaryText(_ summary: HistoricalEnergySummaryValue) -> String {
        var parts: [String] = []

        if let cost = summary.totalCostSEK {
            parts.append("\(Int(cost.rounded()).formatted()) kr")
        }
        if let consumption = summary.totalConsumptionKWh {
            parts.append("\(consumption.formatted(.number.precision(.fractionLength(0...1)))) kWh")
        }
        if parts.isEmpty, let averagePrice = summary.averageSpotPriceOrePerKWh {
            parts.append("Snitt spotpris \(Int(averagePrice.rounded()).formatted()) öre/kWh")
        }

        return parts.isEmpty ? "Prishistorik sparad för aktuell månad" : parts.joined(separator: " · ")
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
