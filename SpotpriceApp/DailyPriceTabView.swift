import SwiftUI
import Charts

struct DailyPriceTabView: View {
    let state: SpotPriceViewModel.State
    @Binding var selectedChartDate: Date?
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let message):
            DashboardErrorView(message: message, onRetry: onRetry)
        case .loaded(let payload):
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                PriceChartSection(payload: payload, selectedChartDate: $selectedChartDate)
                TodayPriceStatsSection(payload: payload)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PriceChartSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    @Binding var selectedChartDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Dagens elpris")
                .font(DS.Font.headline)

            let prices = payload.day.buckets.map { $0.orePerKWh }
            let yDomain = chartYDomain(for: prices)
            let areaBaseline = yDomain.lowerBound
            let selectedBucket = selectedChartDate.flatMap { nearestBucket(to: $0, in: payload.day.buckets) }
            let areaGradient = chartAreaGradient(for: payload.day.buckets)
            let lineGradient = chartLineGradient(for: payload.day.buckets)

            Chart {
                ForEach(payload.day.buckets) { bucket in
                    AreaMark(
                        x: .value("Tid", bucket.start),
                        yStart: .value("Baslinje", areaBaseline),
                        yEnd: .value("öre/kWh", bucket.orePerKWh)
                    )
                    .foregroundStyle(areaGradient)
                }

                ForEach(payload.day.buckets) { bucket in
                    LineMark(
                        x: .value("Tid", bucket.start),
                        y: .value("öre/kWh", bucket.orePerKWh),
                        series: .value("Pris", "Marknad")
                    )
                    .foregroundStyle(lineGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let currentBucket = payload.day.currentBucket {
                    RuleMark(x: .value("Nu", currentBucket.start))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }

                if let selectedBucket {
                    RuleMark(x: .value("Vald tid", selectedBucket.start))
                        .foregroundStyle(DS.Color.secondary.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                        .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                            ChartCalloutView(
                                bucket: selectedBucket,
                                dayData: payload.day,
                                profile: ConsumptionSettings.shared.costProfile
                            )
                        }

                    PointMark(
                        x: .value("Vald tid", selectedBucket.start),
                        y: .value("öre/kWh", selectedBucket.orePerKWh)
                    )
                    .foregroundStyle(chartPriceColor(for: selectedBucket, in: payload.day.buckets))
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

    private func chartAreaGradient(for buckets: [PriceBucket]) -> LinearGradient {
        LinearGradient(
            colors: buckets.map { chartPriceColor(for: $0, in: buckets).opacity(0.26) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func chartLineGradient(for buckets: [PriceBucket]) -> LinearGradient {
        LinearGradient(
            colors: buckets.map { chartPriceColor(for: $0, in: buckets) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func chartPriceColor(for bucket: PriceBucket, in buckets: [PriceBucket]) -> Color {
        let prices = buckets.map { $0.orePerKWh }
        return DS.Color.forPrice(
            bucket.orePerKWh,
            min: prices.min() ?? bucket.orePerKWh,
            max: prices.max() ?? bucket.orePerKWh
        )
    }

    private func nearestBucket(to date: Date, in buckets: [PriceBucket]) -> PriceBucket? {
        buckets.min { lhs, rhs in
            abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
        }
    }
}

private struct TodayPriceStatsSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    private let totalCostService = TotalCostService()

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let averageSpotPrice = averagePrice(payload.day.buckets)
        let minTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.minOre, profile: profile)
        let maxTotal = totalCostService.calculatePricePerKWh(spotPriceOre: payload.day.maxOre, profile: profile)
        let averageTotal = totalCostService.calculatePricePerKWh(spotPriceOre: averageSpotPrice, profile: profile)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
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
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    private func priceStatCard(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(16).monospacedDigit())
                    .foregroundStyle(color)
                Text("kr")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}
