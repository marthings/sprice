//
//  ModernMenuBarView.swift
//  Spotprice
//

import AppKit
import Observation
import SwiftUI

struct ModernMenuBarView: View {
    @Bindable var viewModel: SpotPriceViewModel

    private var state: SpotPriceViewModel.State { viewModel.state }
    private var costProfile: CostProfile { ConsumptionSettings.shared.costProfile }

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Kostnad just nu").font(DS.Font.semibold(14))
                    chartSection
                        .spriceCard(tone: .price)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.handleForeground() }
        }
    }

    @ViewBuilder
    private var historicalSummary: some View {
        if let summary = viewModel.currentMonthHistorySummary {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                    .foregroundStyle(summary.dataCoverage.displayColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Sparad månad")
                            .font(DS.Font.medium(12))
                            .foregroundStyle(.primary)
                        HistoryCoverageBadge(
                            coverage: summary.dataCoverage,
                            horizontalPadding: DS.Spacing.xs
                        )
                    }
                    Text(historySummaryText(summary))
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .spriceCard(tone: .history)
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
            if case .loaded(let payload) = state {
                SpotPriceBarChart(
                    dayData: payload.day,
                    costProfile: costProfile,
                    configuration: .menuBar,
                    tariff: viewModel.currentTariff
                )
            } else {
                loadingStateView
                    .frame(height: DS.Size.chartHeightMenuBar)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: DS.Spacing.md) {
            if case .loading = state {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.0)
                    .tint(.orange)
            } else {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: DS.Size.iconXL, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.6))
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
        if case .loaded(let payload) = state {
            VStack(spacing: DS.Spacing.md) {
                SharedPriceRangeSection(
                    dayData: payload.day,
                    profile: costProfile,
                    style: .compact
                )
                CostCalculationSection(payload: payload, profile: costProfile)
            }
        }
    }

    // MARK: - Helpers

    private var loadedAveragePrice: Double? {
        guard case .loaded(let payload) = state else { return nil }
        return PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
    }

    private var loadingStatusText: String {
        switch state {
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
            parts.append(AppFormatters.wholeKr(cost))
        }
        if let consumption = summary.totalConsumptionKWh {
            parts.append(AppFormatters.kWh(consumption))
        }
        if parts.isEmpty, let averagePrice = summary.averageSpotPriceOrePerKWh {
            parts.append("Snitt spotpris \(AppFormatters.ore(averagePrice))/kWh")
        }

        return parts.isEmpty ? "Prishistorik sparad för aktuell månad" : parts.joined(separator: " · ")
    }

}
