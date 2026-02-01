//
//  ModernMenuBarView.swift
//  Spotprice
//

import SwiftUI
import Charts

struct ModernMenuBarView: View {
    @ObservedObject var viewModel: SpotPriceViewModel
    @ObservedObject var summaryViewModel: SummaryViewModel

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    monthlyStatsSection
                    
                    MenuBarSummaryView(viewModel: summaryViewModel, spotPriceViewModel: viewModel)
                        .background(.ultraThinMaterial)
                        .cornerRadius(DS.Radius.lg)

                    chartSection
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))

                    quickStats
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
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: DS.Size.headerIconSize, height: DS.Size.headerIconSize)
                    .overlay {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: DS.Size.iconSmall, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                Text("Spotpris")
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
                        .background(.ultraThinMaterial)
                        .cornerRadius(DS.Radius.full)
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
                        .background(.ultraThinMaterial)
                        .cornerRadius(DS.Radius.full)
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
                SpotPriceBarChart(dayData: payload.day, configuration: .menuBar)
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
                        color: DS.Color.error,
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

                costCalculationSection(payload: payload)
            }
        }
    }

    // MARK: - Monthly Stats Section

    @ViewBuilder
    private var monthlyStatsSection: some View {
        if let consumption = viewModel.monthlyConsumption {
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

                    if case .loaded(let payload) = viewModel.state {
                        let avgPrice = averagePrice(payload.day.buckets)
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
                TopConsumptionDaysCard(dailyValues: viewModel.dailyConsumption)
            }
        } else if !ConsumptionSettings.shared.isConfigured {
            SettingsLink {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.blue)
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
                .padding(DS.Spacing.md)
                .background(.ultraThinMaterial)
                .cornerRadius(DS.Radius.lg)
            }
            .buttonStyle(.plain)
        } else if let error = viewModel.consumptionError {
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
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Radius.lg)
        }
    }

    // MARK: - Cost Calculation Section

    private func costCalculationSection(payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        let currentPrice = getCurrentPriceOrAverage(payload)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Text("Kostnad med detta pris")
                    .font(DS.Font.semibold(14))
                    .foregroundStyle(.primary)

                if let price = getCurrentPrice(payload) {
                    Text("(\(Int(price.rounded())) öre/kWh)")
                        .font(DS.Font.medium(11))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
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
                    color: DS.Color.warning
                )

                CostCardView(
                    title: "Värmepump/dag",
                    mainCost: CostCardView.calculateCost(kWh: 24.0, priceInOre: currentPrice),
                    description: "~24 kWh",
                    color: DS.Color.error
                )

                CostCardView(
                    title: "Ladda bilen",
                    mainCost: CostCardView.calculateCost(kWh: 45.0, priceInOre: currentPrice),
                    description: "~45 kWh",
                    color: DS.Color.success
                )
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Helpers

    private func getCurrentPrice(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double? {
        let now = Date()
        return payload.day.buckets.first { $0.start <= now && $0.end > now }?.orePerKWh
    }

    private func getCurrentPriceOrAverage(_ payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        getCurrentPrice(payload) ?? averagePrice(payload.day.buckets)
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

// MARK: - Consumption Stat Card

struct ConsumptionStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium))
                .foregroundStyle(color.gradient)
                .frame(width: DS.Size.headerIconSize)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(DS.Font.medium(11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Radius.md)
    }
}

// MARK: - Top Consumption Days Card

struct TopConsumptionDaysCard: View {
    let dailyValues: [DailyConsumption]

    private var topDays: [DailyConsumption] {
        Array(
            dailyValues
                .sorted { $0.kWh > $1.kWh }
                .prefix(3)
                .sorted { $0.date < $1.date }  // Sort by date for display
        )
    }

    private var maxKWh: Double {
        topDays.map(\.kWh).max() ?? 1
    }

    private var hasData: Bool {
        !topDays.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: DS.Size.iconSmall))
                    .foregroundStyle(.orange.gradient)
                Text("Effekttoppar denna månad")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            if hasData {
                Chart(topDays) { day in
                    BarMark(
                        x: .value("Dag", day.date, unit: .day),
                        y: .value("kWh", day.kWh)
                    )
                    .foregroundStyle(barColor(for: day.kWh).gradient)
                    .cornerRadius(DS.Radius.sm)
                    .annotation(position: .top, spacing: DS.Spacing.xxs) {
                        Text("\(Int(day.kWh.rounded()))")
                            .font(DS.Font.bold(11).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(dayLabel(date))
                                    .font(DS.Font.micro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(maxKWh * 1.3))
                .frame(height: 70)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: DS.Size.iconMedium))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Väntar på data")
                            .font(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 70)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Radius.md)
    }

    private func barColor(for kWh: Double) -> Color {
        let ratio = kWh / maxKWh
        if ratio > 0.9 { return DS.Color.error }
        if ratio > 0.7 { return DS.Color.warning }
        return .blue
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
