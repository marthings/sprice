//
//  ModernMenuBarView.swift
//  Spotprice
//

import SwiftUI

struct ModernMenuBarView: View {
    @ObservedObject var viewModel: SpotPriceViewModel
    @ObservedObject var summaryViewModel: SummaryViewModel

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(spacing: 14) {
                    MenuBarSummaryView(viewModel: summaryViewModel, spotPriceViewModel: viewModel)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)

                    chartSection
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    quickStats
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 340, height: 620)
        .font(.custom("Avenir", size: 13))
    }

    // MARK: - Header

    private var menuHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeat(.continuous))
                    }

                Text("Spotpris")
                    .font(.custom("Avenir", size: 16).weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial)
                    .cornerRadius(999)
            }
            .buttonStyle(.plain)
            .help("Avsluta")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: 8) {
            if case .loaded(let payload) = viewModel.state {
                SpotPriceBarChart(dayData: payload.day, configuration: .menuBar)
            } else {
                loadingStateView
                    .frame(height: 180)
            }
        }
        .padding(.vertical, 8)
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            Group {
                if case .loading = viewModel.state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.0)
                        .tint(.orange)
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }

            Text(loadingStatusText)
                .font(.custom("Avenir", size: 14).weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Quick Stats

    @ViewBuilder
    private var quickStats: some View {
        if case .loaded(let payload) = viewModel.state {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    StatCardView(
                        title: "Lägsta",
                        value: "\(Int(payload.day.minOre.rounded()))",
                        unit: "öre",
                        color: .green,
                        icon: "arrow.down.circle.fill"
                    )

                    StatCardView(
                        title: "Högsta",
                        value: "\(Int(payload.day.maxOre.rounded()))",
                        unit: "öre",
                        color: .red,
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

                // Monthly stats section
                monthlyStatsSection

                costCalculationSection(payload: payload)
            }
        }
    }

    // MARK: - Monthly Stats Section

    @ViewBuilder
    private var monthlyStatsSection: some View {
        if let consumption = viewModel.monthlyConsumption {
            VStack(alignment: .leading, spacing: 12) {
                Text("Månadsstatistik")
                    .font(.custom("Avenir", size: 14).weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    // Consumption card
                    ConsumptionStatCard(
                        title: "Förbrukning",
                        value: "\(Int(consumption.totalKWh.rounded()))",
                        unit: "kWh",
                        color: .purple,
                        icon: "bolt.circle.fill"
                    )

                    // Estimated cost this month (using average price)
                    if case .loaded(let payload) = viewModel.state {
                        let avgPrice = averagePrice(payload.day.buckets)
                        let estimatedCost = (avgPrice / 100.0) * consumption.totalKWh
                        ConsumptionStatCard(
                            title: "Uppskattad kostnad",
                            value: String(format: "%.0f", estimatedCost),
                            unit: "kr",
                            color: .orange,
                            icon: "creditcard.fill"
                        )
                    }
                }
            }
        } else if let error = viewModel.consumptionError {
            // Show error state
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kunde inte hämta förbrukning")
                        .font(.custom("Avenir", size: 12).weight(.medium))
                        .foregroundStyle(.primary)
                    Text(error)
                        .font(.custom("Avenir", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Radius.lg)
        }
    }

    // MARK: - Cost Calculation Section

    private func costCalculationSection(payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        let currentPrice = getCurrentPriceOrAverage(payload)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Kostnad med detta pris")
                    .font(.custom("Avenir", size: 14).weight(.semibold))
                    .foregroundStyle(.primary)

                if let price = getCurrentPrice(payload) {
                    Text("(\(Int(price.rounded())) öre/kWh)")
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                CostCardView(
                    title: "Dusch (10 min)",
                    mainCost: CostCardView.calculateCost(kWh: 6.0, priceInOre: currentPrice),
                    description: "~6 kWh",
                    color: .blue
                )

                CostCardView(
                    title: "Pizza i ugn",
                    mainCost: CostCardView.calculateCost(kWh: 1.1, priceInOre: currentPrice),
                    description: "~1,1 kWh",
                    color: .orange
                )

                CostCardView(
                    title: "Värmepump/dag",
                    mainCost: CostCardView.calculateCost(kWh: 24.0, priceInOre: currentPrice),
                    description: "~24 kWh",
                    color: .red
                )

                CostCardView(
                    title: "Ladda bilen",
                    mainCost: CostCardView.calculateCost(kWh: 45.0, priceInOre: currentPrice),
                    description: "~45 kWh",
                    color: .green
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double? {
        let now = Date()
        if let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) {
            return currentBucket.orePerKWh
        }
        return nil
    }

    private func getCurrentPriceOrAverage(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        return getCurrentPrice(payload) ?? averagePrice(payload.day.buckets)
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        let sum = buckets.reduce(0) { $0 + $1.orePerKWh }
        return sum / Double(buckets.count)
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

// MARK: - Consumption Stat Card

struct ConsumptionStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color.gradient)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.custom("Avenir", size: 16).weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
