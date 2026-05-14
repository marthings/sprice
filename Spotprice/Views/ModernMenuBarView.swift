//
//  ModernMenuBarView.swift
//  Spotprice
//

import SwiftUI

struct ModernMenuBarView: View {
    var viewModel: SpotPriceViewModel
    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Kostnad just nu").font(DS.Font.semibold(14))
                    chartSection
                        .glassCard(cornerRadius: DS.Radius.md)
                    quickStats
                    MonthlyStatsSection(
                        consumption: viewModel.monthlyConsumption,
                        powerPeaks: viewModel.powerPeaks,
                        consumptionError: viewModel.consumptionError,
                        isConfigured: ConsumptionSettings.shared.isConfigured,
                        averagePrice: loadedAveragePrice,
                        preciseCost: viewModel.preciseMonthlyCost
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
                confidenceHeader
                quickStatsCards(for: payload)
                CostCalculationSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            }
        }
    }

    @ViewBuilder
    private func quickStatsCards(for payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        let profile = ConsumptionSettings.shared.costProfile

        // Section header explaining what the stats represent
        HStack(spacing: DS.Spacing.xs) {
            if profile.isSpotFollowingRetailContract {
                Text("Prisspann idag (kr/kWh)")
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Marknadens prisspann idag (kr/kWh)")
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, DS.Spacing.xxs)

        HStack(spacing: DS.Spacing.sm) {
            if profile.isSpotFollowingRetailContract {
                // Show total cost stats for spot-following contracts
                let minTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.minOre, profile: profile)
                let maxTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.maxOre, profile: profile)
                let avgTotal = totalCostService.calculatePricePerKWh(spotPriceOre: averagePrice(payload.day.buckets), profile: profile)

                StatCardView(
                    title: "Lägsta",
                    value: minTotal.formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: DS.Color.success,
                    icon: "arrow.down.circle.fill"
                )

                StatCardView(
                    title: "Högsta",
                    value: maxTotal.formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: DS.Color.danger,
                    icon: "arrow.up.circle.fill"
                )

                StatCardView(
                    title: "Snitt",
                    value: avgTotal.formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: .blue,
                    icon: "chart.line.uptrend.xyaxis"
                )
            } else {
                // Show market quarter price stats for fixed/variable contracts
                StatCardView(
                    title: "Lägsta",
                    value: (payload.day.minOre / 100).formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: DS.Color.success,
                    icon: "arrow.down.circle.fill"
                )

                StatCardView(
                    title: "Högsta",
                    value: (payload.day.maxOre / 100).formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: DS.Color.danger,
                    icon: "arrow.up.circle.fill"
                )

                StatCardView(
                    title: "Snitt",
                    value: (averagePrice(payload.day.buckets) / 100).formatted(.number.precision(.fractionLength(2))),
                    unit: "kr",
                    color: .blue,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }

        // For fixed/variable contracts, add comparison to contract price
        if !profile.isSpotFollowingRetailContract, let contractPrice = profile.contractPriceOrePerKWh {
            let avgMarket = averagePrice(payload.day.buckets)
            let difference = avgMarket - contractPrice
            let isMarketCheaper = difference < 0

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isMarketCheaper ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isMarketCheaper ? DS.Color.success : DS.Color.danger)

                Text(isMarketCheaper 
                    ? "Marknaden är i snitt billigare än ditt avtal idag" 
                    : "Ditt avtal är billigare än marknaden i snitt idag")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, DS.Spacing.xxs)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var confidenceHeader: some View {
        let profile = ConsumptionSettings.shared.costProfile
        HStack(spacing: DS.Spacing.sm) {
            if let label = profile.confidence.menuBarLabel {
                Text(label)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.quaternary.opacity(0.6), in: .capsule)
            }

            if profile.confidence == .estimated {
                Text("Förbättra precisionen: lägg till elhandelsavtal eller elnätsuppgifter.")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

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
}
