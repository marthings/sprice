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
                SharedPriceRangeSection(
                    dayData: payload.day,
                    profile: ConsumptionSettings.shared.costProfile,
                    style: .regular
                )
                
                MarketContractExplanation(profile: ConsumptionSettings.shared.costProfile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PriceChartSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    @Binding var selectedChartDate: Date?

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Dagens totalpris")
                    .font(DS.Font.headline)

                Text("Kurvan visar priset per kWh under dagen med spotpris, skatter och dina valda avgifter inräknade.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let profile = ConsumptionSettings.shared.costProfile
            let prices = payload.day.buckets.map { chartPriceValue(for: $0, profile: profile) }
            let yDomain = chartYDomain(for: prices)
            let selectedBucket = selectedChartDate.flatMap { nearestBucket(to: $0, in: payload.day.buckets) }
            let lineGradient = chartLineGradient(for: payload.day.buckets, profile: profile)

            Chart {
                ForEach(payload.day.buckets) { bucket in
                    LineMark(
                        x: .value("Tid", bucket.start),
                        y: .value("kr/kWh", chartPriceValue(for: bucket, profile: profile)),
                        series: .value("Pris", "Total")
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
                            IOSChartCalloutView(
                                bucket: selectedBucket,
                                dayData: payload.day,
                                profile: ConsumptionSettings.shared.costProfile
                            )
                        }

                    PointMark(
                        x: .value("Vald tid", selectedBucket.start),
                        y: .value("kr/kWh", chartPriceValue(for: selectedBucket, profile: profile))
                    )
                    .foregroundStyle(chartPriceColor(for: selectedBucket, in: payload.day.buckets, profile: profile))
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
                            Text(price, format: .number.precision(.fractionLength(2)))
                                .font(DS.Font.micro)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedChartDate)
            .frame(height: 260)
            .padding()
            .glassCard(cornerRadius: DS.Radius.lg)
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

    private func chartLineGradient(for buckets: [PriceBucket], profile: CostProfile) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: chartGradientStops(for: buckets, profile: profile)),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func chartGradientStops(for buckets: [PriceBucket], profile: CostProfile) -> [Gradient.Stop] {
        guard !buckets.isEmpty else {
            return [Gradient.Stop(color: DS.Color.warning, location: 0)]
        }

        let prices = buckets.map { chartPriceValue(for: $0, profile: profile) }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? minPrice
        let lastIndex = max(buckets.count - 1, 1)

        return buckets.enumerated().map { index, bucket in
            Gradient.Stop(
                color: smoothPriceColor(
                    for: chartPriceValue(for: bucket, profile: profile),
                    min: minPrice,
                    max: maxPrice
                ),
                location: Double(index) / Double(lastIndex)
            )
        }
    }

    private func chartPriceColor(for bucket: PriceBucket, in buckets: [PriceBucket], profile: CostProfile) -> Color {
        let prices = buckets.map { chartPriceValue(for: $0, profile: profile) }
        let value = chartPriceValue(for: bucket, profile: profile)
        return smoothPriceColor(
            for: value,
            min: prices.min() ?? value,
            max: prices.max() ?? value
        )
    }

    private func chartPriceValue(for bucket: PriceBucket, profile: CostProfile) -> Double {
        totalCostService.calculatePricePerKWh(spotPriceOre: bucket.orePerKWh, profile: profile)
    }

    private func smoothPriceColor(for price: Double, min: Double, max: Double) -> Color {
        let range = max - min
        guard range > 0 else { return DS.Color.warning }

        let normalized = Swift.min(Swift.max((price - min) / range, 0), 1)
        switch normalized {
        case ..<0.5:
            return interpolateColor(
                from: Color(red: 0.02, green: 0.56, blue: 0.24),
                to: Color(red: 0.95, green: 0.38, blue: 0.02),
                progress: normalized / 0.5
            )
        default:
            return interpolateColor(
                from: Color(red: 0.95, green: 0.38, blue: 0.02),
                to: Color(red: 0.82, green: 0.04, blue: 0.04),
                progress: (normalized - 0.5) / 0.5
            )
        }
    }

    private func interpolateColor(from start: Color, to end: Color, progress: Double) -> Color {
        let clampedProgress = Float(Swift.min(Swift.max(progress, 0), 1))
        let startComponents = start.resolve(in: EnvironmentValues())
        let endComponents = end.resolve(in: EnvironmentValues())

        return Color(
            red: Double(startComponents.red + ((endComponents.red - startComponents.red) * clampedProgress)),
            green: Double(startComponents.green + ((endComponents.green - startComponents.green) * clampedProgress)),
            blue: Double(startComponents.blue + ((endComponents.blue - startComponents.blue) * clampedProgress))
        )
    }

    private func nearestBucket(to date: Date, in buckets: [PriceBucket]) -> PriceBucket? {
        buckets.min { lhs, rhs in
            abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
        }
    }
}

private struct MarketContractExplanation: View {
    let profile: CostProfile

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Så beräknas priset")
                .font(DS.Font.headline)

            Text(explanationText)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Fasta delar i totalpriset")
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(.primary)

                ForEach(staticCostRows, id: \.title) { row in
                    HStack(spacing: DS.Spacing.sm) {
                        Text(row.title)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                        Spacer(minLength: DS.Spacing.sm)
                        Text(row.value, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.micro.monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("kr/kWh")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    private var explanationText: String {
        switch profile.retailContractType {
        case .spotPriceMarkup:
            return "Grafen visar marknadens kvartspris. Din kostnad följer kurvan och lägger till påslag, skatter och valda elnätskostnader."
        case .variableMonthlyPrice:
            return "Grafen visar marknadens kvartspris som jämförelse. Din elhandelskostnad beräknas från ditt rörliga månadspris."
        case .fixedPrice:
            return "Grafen visar marknadens kvartspris som jämförelse. Din elhandelskostnad beräknas från ditt fasta avtalade pris."
        }
    }

    private var staticCostRows: [(title: String, value: Double)] {
        let baseCost = totalCostService.calculateTotalCost(
            kWh: 1,
            spotPriceOre: 0,
            profile: profile,
            hoursInPeriod: 1
        )

        var rows: [(String, Double)] = []

        switch profile.retailContractType {
        case .spotPriceMarkup:
            let retailFees = baseCost.providerSurchargeKr + baseCost.providerMonthlyFeeKr
            if retailFees > 0 {
                rows.append(("Elhandel utöver spot", retailFees))
            }
        case .variableMonthlyPrice, .fixedPrice:
            if baseCost.spotCostKr > 0 {
                rows.append((profile.retailContractDisplayName, baseCost.spotCostKr))
            }
            if baseCost.providerMonthlyFeeKr > 0 {
                rows.append(("Elhandel månadsavgift", baseCost.providerMonthlyFeeKr))
            }
        }

        let gridFees = baseCost.gridEnergyCostKr + baseCost.fixedFeeCostKr + baseCost.powerTariffCostKr
        if gridFees > 0 {
            rows.append(("Elnät", gridFees))
        }

        let taxesAndFees = baseCost.energyTaxKr + baseCost.certificateFeeKr
        if taxesAndFees > 0 {
            rows.append(("Skatt och avgifter", taxesAndFees))
        }

        return rows
    }
}
