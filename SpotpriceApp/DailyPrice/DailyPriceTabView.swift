import SwiftUI
import Charts

struct DailyPriceTabView: View {
    let state: SpotPriceViewModel.State
    let costProfile: CostProfile
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
                PriceChartSection(
                    payload: payload,
                    costProfile: costProfile,
                    selectedChartDate: $selectedChartDate
                )
                SharedPriceRangeSection(
                    dayData: payload.day,
                    profile: costProfile,
                    style: .regular
                )

                MarketContractExplanation(profile: costProfile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PriceChartSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let costProfile: CostProfile
    @Binding var selectedChartDate: Date?

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

            PriceChartPlot(
                day: payload.day,
                profile: costProfile,
                selectedChartDate: $selectedChartDate
            )
        }
    }
}

private struct PriceChartPlot: View {
    let day: DayChartData
    let profile: CostProfile
    @Binding var selectedChartDate: Date?

    var body: some View {
        let series = TotalPriceChartSeries(day: day, profile: profile)
        let selectedBucket = selectedChartDate.flatMap { nearestBucket(to: $0, in: day.buckets) }

        Chart {
            ForEach(series.buckets) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("kr/kWh", series.price(for: bucket)),
                    series: .value("Pris", "Total")
                )
                .foregroundStyle(series.lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if let currentBucket = day.currentBucket {
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
                            dayData: day,
                            profile: profile
                        )
                    }

                PointMark(
                    x: .value("Vald tid", selectedBucket.start),
                    y: .value("kr/kWh", series.price(for: selectedBucket))
                )
                .foregroundStyle(series.color(for: selectedBucket))
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
        .chartYScale(domain: series.yDomain)
        .chartXSelection(value: $selectedChartDate)
        .frame(height: 260)
        .padding()
        .glassCard()
        .zIndex(1)
        .accessibilityHint("Dra över grafen för att se pris vid en viss tid.")
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
        .glassCard()
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
