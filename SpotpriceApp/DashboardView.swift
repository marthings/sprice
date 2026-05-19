import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel = SpotPriceViewModel()
    private let totalCostService = TotalCostService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    content
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sprice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Uppdatera")
                }
            }
            .task {
                if case .idle = viewModel.state {
                    await viewModel.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .failed(let message):
            errorView(message)
        case .loaded(let payload):
            dashboardContent(payload)
        }
    }

    private var loadingView: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(DS.Color.warning)
            Text("Hämtar elpriser")
                .font(DS.Font.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: DS.Size.iconXL, weight: .light))
                .foregroundStyle(.secondary)
            Text("Kunde inte hämta priser")
                .font(DS.Font.headline)
            Text(message)
                .font(DS.Font.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(.background, in: .rect(cornerRadius: DS.Radius.lg))
    }

    private func dashboardContent(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            currentCostHero(payload)
            chartSection(payload)
            todayStatsSection(payload)
            CostExamplesSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            monthlySection(payload)
        }
    }

    private func currentCostHero(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? averagePrice(payload.day.buckets)
        let totalPrice = totalCostService.calculatePricePerKWh(spotPriceOre: spotPrice, profile: profile)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)

        return VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Kostnad just nu")
                        .font(DS.Font.callout)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                        Text(totalPrice, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.bold(44).monospacedDigit())
                            .foregroundStyle(DS.Color.forCategory(category))
                        Text("kr/kWh")
                            .font(DS.Font.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                PriceLevelBadge(category: category)
            }

            HStack(spacing: DS.Spacing.md) {
                metricInline(title: "Spotpris", value: payload.currentDisplay, unit: "öre")
                if let trend = viewModel.state.trendPrices {
                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: trend.current, next: trend.next)
                        metricInline(
                            title: "Nästa kvart",
                            value: Int(trend.next.rounded()).formatted(),
                            unit: "öre"
                        )
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.background, in: .rect(cornerRadius: DS.Radius.lg))
    }

    private func chartSection(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Dagens elpris")
                .font(DS.Font.headline)

            let prices = payload.day.buckets.map { $0.orePerKWh }
            let minPrice = (prices.min() ?? 0) * 0.95
            let maxPrice = (prices.max() ?? 0) * 1.05

            Chart {
                ForEach(payload.day.buckets) { bucket in
                    AreaMark(
                        x: .value("Tid", bucket.start),
                        y: .value("öre/kWh", bucket.orePerKWh)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.Color.warning.opacity(0.28), DS.Color.warning.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Tid", bucket.start),
                        y: .value("öre/kWh", bucket.orePerKWh)
                    )
                    .foregroundStyle(DS.Color.warning)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                if let currentBucket = payload.day.currentBucket {
                    RuleMark(x: .value("Nu", currentBucket.start))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(.tertiary)
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.hour()))
                                .font(DS.Font.micro)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.tertiary)
                    AxisTick()
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text("\(Int(price.rounded()))")
                                .font(DS.Font.micro)
                        }
                    }
                }
            }
            .chartYScale(domain: minPrice...maxPrice)
            .frame(height: 260)
        }
        .padding(DS.Spacing.lg)
        .background(.background, in: .rect(cornerRadius: DS.Radius.lg))
    }

    private func todayStatsSection(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        let profile = ConsumptionSettings.shared.costProfile
        let averageSpotPrice = averagePrice(payload.day.buckets)
        let minTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.minOre, profile: profile)
        let maxTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.maxOre, profile: profile)
        let averageTotal = totalCostService.calculatePricePerKWh(spotPriceOre: averageSpotPrice, profile: profile)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Prisspann idag")
                .font(DS.Font.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                priceStatCard(title: "Lägsta", value: minTotal, color: DS.Color.success, icon: "arrow.down.circle.fill")
                priceStatCard(title: "Snitt", value: averageTotal, color: DS.Color.info, icon: "chart.line.uptrend.xyaxis")
                priceStatCard(title: "Högsta", value: maxTotal, color: DS.Color.danger, icon: "arrow.up.circle.fill")
            }

            if let basisText = profile.retailContractCostBasisText {
                Label(basisText, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.background, in: .rect(cornerRadius: DS.Radius.lg))
    }

    private func monthlySection(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Förbrukning")
                .font(DS.Font.headline)

            if let consumption = viewModel.monthlyConsumption {
                let estimatedCost = estimatedMonthlyCost(consumption: consumption, payload: payload)
                HStack(spacing: DS.Spacing.sm) {
                    monthlyMetricCard(
                        title: consumption.monthName,
                        value: Int(consumption.totalKWh.rounded()).formatted(),
                        unit: "kWh",
                        icon: "bolt.fill",
                        color: DS.Color.warning
                    )
                    monthlyMetricCard(
                        title: "Uppskattat",
                        value: Int(estimatedCost.rounded()).formatted(),
                        unit: "kr",
                        icon: "creditcard.fill",
                        color: DS.Color.info
                    )
                }
            } else if let error = viewModel.consumptionError {
                statusRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Kunde inte hämta förbrukning",
                    message: error,
                    color: DS.Color.warning
                )
            } else if !ConsumptionSettings.shared.isConfigured {
                statusRow(
                    icon: "gearshape.fill",
                    title: "Konfigurera förbrukning",
                    message: "Lägg till dina uppgifter för att se månadsstatistik.",
                    color: .secondary
                )
            } else {
                statusRow(
                    icon: "hourglass",
                    title: "Förbrukning laddas",
                    message: "Månadsstatistik visas när den är tillgänglig.",
                    color: .secondary
                )
            }
        }
        .padding(DS.Spacing.lg)
        .background(.background, in: .rect(cornerRadius: DS.Radius.lg))
    }

    private func metricInline(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(DS.Font.semibold(15).monospacedDigit())
                Text(unit)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func priceStatCard(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(16).monospacedDigit())
                    .foregroundStyle(color)
                Text("kr")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: DS.Radius.md))
    }

    private func monthlyMetricCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(18).monospacedDigit())
                    Text(unit)
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: DS.Radius.md))
    }

    private func statusRow(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.callout)
                Text(message)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: DS.Radius.md))
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }

    private func estimatedMonthlyCost(consumption: ConsumptionData, payload: SpotPriceViewModel.CurrentAndDay) -> Double {
        if let preciseCost = viewModel.preciseMonthlyCost {
            return preciseCost.totalCostKr
        }

        let profile = ConsumptionSettings.shared.costProfile
        let averageSpotPrice = averagePrice(payload.day.buckets)
        let cost = totalCostService.calculateTotalCost(
            kWh: consumption.totalKWh,
            spotPriceOre: averageSpotPrice,
            profile: profile,
            hoursInPeriod: 730
        )
        return cost.totalKr
    }
}

#Preview {
    DashboardView()
}
