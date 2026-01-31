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
                GlassEffectContainer(spacing: 14) {
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
                GlassEffectContainer(spacing: 10) {
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
                }

                costCalculationSection(payload: payload)
            }
        }
    }

    // MARK: - Cost Calculation Section

    private func costCalculationSection(payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Kostnad med detta pris")
                    .font(.custom("Avenir", size: 14).weight(.semibold))
                    .foregroundStyle(.primary)

                if let currentPrice = getCurrentPrice(payload) {
                    Text("(\(Int(currentPrice.rounded())) öre/kWh)")
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            let currentPrice = getCurrentPriceOrAverage(payload)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)) {
                GlassEffectContainer {
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
