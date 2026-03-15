//
//  ModernMenuBarView.swift
//  Spotprice
//

import SwiftUI

struct ModernMenuBarView: View {
    var viewModel: SpotPriceViewModel
    var summaryViewModel: SummaryViewModel

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Spotpriset").font(DS.Font.semibold(14))
                    chartSection
                        .glassCard(cornerRadius: DS.Radius.md)
                    quickStats
                    MonthlyStatsSection(
                        consumption: viewModel.monthlyConsumption,
                        powerPeaks: viewModel.powerPeaks,
                        consumptionError: viewModel.consumptionError,
                        isConfigured: ConsumptionSettings.shared.isConfigured,
                        averagePrice: loadedAveragePrice,
                        preciseCost: viewModel.preciseMonthlyCost,
                        tariff: viewModel.currentTariff
                    )
                    MenuBarSummaryView(viewModel: summaryViewModel, spotPriceViewModel: viewModel)
                        .glassCard(cornerRadius: DS.Radius.lg)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: DS.Size.menuBarWidth, height: DS.Size.menuBarHeight)
        .font(DS.Font.callout)
    }

    // MARK: - Header

    private var menuHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
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
                .buttonStyle(.plain)
                .help("Inställningar")

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Size.closeButtonIconSize, weight: .bold))
                        .frame(width: DS.Size.closeButtonSize, height: DS.Size.closeButtonSize)
                        .foregroundStyle(.primary)
                        .background(.ultraThinMaterial, in: .circle)
                }
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
                HStack(spacing: DS.Spacing.sm) {
                    if let tariff = viewModel.currentTariff {
                        let totalCostService = TotalCostService()
                        let minTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.minOre, tariff: tariff)
                        let maxTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.maxOre, tariff: tariff)
                        let avgTotal = totalCostService.calculatePricePerKWh(spotPriceOre: averagePrice(payload.day.buckets), tariff: tariff)
                        
                        StatCardView(
                            title: "Lägsta",
                            value: String(format: "%.2f", minTotal),
                            unit: "kr",
                            color: DS.Color.success,
                            icon: "arrow.down.circle.fill"
                        )

                        StatCardView(
                            title: "Högsta",
                            value: String(format: "%.2f", maxTotal),
                            unit: "kr",
                            color: DS.Color.danger,
                            icon: "arrow.up.circle.fill"
                        )

                        StatCardView(
                            title: "Snitt",
                            value: String(format: "%.2f", avgTotal),
                            unit: "kr",
                            color: .blue,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    } else {
                        StatCardView(
                            title: "Lägsta",
                            value: "\(Int(payload.day.minOre.rounded()))",
                            unit: "öre",
                            color: DS.Color.success,
                            icon: "arrow.down.circle.fill"
                        )

                        StatCardView(
                            title: "Högsta",
                            value: "\(Int(payload.day.maxOre.rounded()))",
                            unit: "öre",
                            color: DS.Color.danger,
                            icon: "arrow.up.circle.fill"
                        )

                        StatCardView(
                            title: "Snitt",
                            value: "\(Int(averagePrice(payload.day.buckets).rounded()))",
                            unit: "öre",
                            color: .blue,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                }

                CostCalculationSection(payload: payload, tariff: viewModel.currentTariff)
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
            return "Tryck Uppdatera för att ladda dagens spotpriser"
        case .loading:
            return "Hämtar aktuella spotpriser..."
        case .failed(let message):
            return message
        case .loaded:
            return ""
        }
    }
}
