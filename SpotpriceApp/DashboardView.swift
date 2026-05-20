import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel = SpotPriceViewModel()
    @State private var isShowingSettings = false
    @State private var selectedChartDate: Date?
    private let totalCostService = TotalCostService()

    var body: some View {
        NavigationStack {
            ZStack {
                Image("bg")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        dashboardHeader
                        content
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Inställningar")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                AppSettingsView()
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

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("Sprice")
                .font(DS.Font.bold(40))
                .foregroundStyle(.primary)

            Text(settingsSummary)
                .font(DS.Font.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.top, DS.Spacing.sm)
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
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    private func dashboardContent(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            currentCostHero(payload)
            chartSection(payload)
            todayStatsSection(payload)
            CostExamplesSection(payload: payload, profile: ConsumptionSettings.shared.costProfile)
            MonthlyConsumptionSection(
                consumption: viewModel.monthlyConsumption,
                powerPeaks: viewModel.powerPeaks,
                consumptionError: viewModel.consumptionError,
                isConfigured: ConsumptionSettings.shared.isConfigured,
                averagePrice: averagePrice(payload.day.buckets),
                preciseCost: viewModel.preciseMonthlyCost,
                profile: ConsumptionSettings.shared.costProfile,
                onConfigureConsumption: {
                    isShowingSettings = true
                }
            )
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
                        .font(DS.Font.headline)
                        .foregroundStyle(.primary)
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
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    private func chartSection(_ payload: SpotPriceViewModel.CurrentAndDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Dagens elpris")
                .font(DS.Font.headline)

            let prices = payload.day.buckets.map { $0.orePerKWh }
            let yDomain = chartYDomain(for: prices)
            let areaBaseline = yDomain.lowerBound
            let selectedBucket = selectedChartDate.flatMap { nearestBucket(to: $0, in: payload.day.buckets) }

            Chart {
                ForEach(payload.day.buckets) { bucket in
                    let categoryColor = DS.Color.forCategory(bucket.category)

                    AreaMark(
                        x: .value("Tid", bucket.start),
                        yStart: .value("Baslinje", areaBaseline),
                        yEnd: .value("öre/kWh", bucket.orePerKWh)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                categoryColor.opacity(0.30),
                                categoryColor.opacity(0.10),
                                categoryColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Tid", bucket.start),
                        y: .value("öre/kWh", bucket.orePerKWh)
                    )
                    .foregroundStyle(categoryColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                if let currentBucket = payload.day.currentBucket {
                    RuleMark(x: .value("Nu", currentBucket.start))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }

                if let selectedBucket {
                    RuleMark(x: .value("Vald tid", selectedBucket.start))
                        .foregroundStyle(.secondary.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                        .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                            chartTooltip(for: selectedBucket)
                        }

                    PointMark(
                        x: .value("Vald tid", selectedBucket.start),
                        y: .value("öre/kWh", selectedBucket.orePerKWh)
                    )
                    .foregroundStyle(DS.Color.forCategory(selectedBucket.category))
                    .symbolSize(70)
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
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedChartDate)
            .frame(height: 260)
            .zIndex(1)
            .accessibilityHint("Dra över grafen för att se pris vid en viss tid.")
        }
        .padding(DS.Spacing.lg)
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    private func chartTooltip(for bucket: PriceBucket) -> some View {
        let profile = ConsumptionSettings.shared.costProfile
        let totalPrice = totalCostService.calculatePricePerKWh(spotPriceOre: bucket.orePerKWh, profile: profile)

        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(bucket.start.formatted(.dateTime.hour().minute()))
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(totalPrice, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.semibold(15).monospacedDigit())
                    .foregroundStyle(DS.Color.forCategory(bucket.category))
                Text("kr/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(bucket.orePerKWh.rounded())) öre spot")
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Color.brand.opacity(0.18), in: .rect(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(DS.Color.outline.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .zIndex(10)
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
                priceStatCard(title: "Lägsta", value: minTotal, color: DS.Color.success)
                priceStatCard(title: "Snitt", value: averageTotal, color: DS.Color.info)
                priceStatCard(title: "Högsta", value: maxTotal, color: DS.Color.danger)
            }

            if let basisText = profile.retailContractCostBasisText {
                Label(basisText, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .iosGlassCard(cornerRadius: DS.Radius.lg)
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

    private func priceStatCard(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {

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
        .padding(.vertical, DS.Spacing.sm)
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }

    private var settingsSummary: String {
        let profile = ConsumptionSettings.shared.costProfile
        var parts = [profile.priceArea, profile.retailContractDisplayName]

        if let gridCompanyName = profile.gridCompanyName, !gridCompanyName.isEmpty {
            parts.append(gridCompanyName)
        }

        return parts.joined(separator: " ")
    }

    private func chartYDomain(for prices: [Double]) -> ClosedRange<Double> {
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return 0...1
        }

        if minPrice == maxPrice {
            let padding = max(abs(minPrice) * 0.1, 1)
            return (minPrice - padding)...(maxPrice + padding)
        }

        let padding = (maxPrice - minPrice) * 0.08
        return max(0, minPrice - padding)...(maxPrice + padding)
    }

    private func nearestBucket(to date: Date, in buckets: [PriceBucket]) -> PriceBucket? {
        buckets.min { lhs, rhs in
            abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
        }
    }

}

extension View {
    func iosGlassCard(cornerRadius: CGFloat, material: Material = .thinMaterial) -> some View {
        background(material, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
    }
}

#Preview {
    DashboardView()
}
