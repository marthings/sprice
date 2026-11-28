import SwiftUI
import Charts

struct DailyPriceTabView: View {
    let state: SpotPriceViewModel.State
    let costProfile: CostProfile
    let notices: [FetchNotice]
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let notice):
            DashboardErrorView(notice: notice, onRetry: onRetry)
        case .loaded(let payload):
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                PriceChartSection(
                    payload: payload,
                    costProfile: costProfile
                )
                SharedPriceRangeSection(
                    dayData: payload.day,
                    profile: costProfile,
                    style: .regular
                )

                MarketContractExplanation(profile: costProfile)
                FetchNoticeStack(notices: notices)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PriceChartSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let costProfile: CostProfile

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Dagens totalpris",
                paragraphs: [
                    "Kurvan visar vad en kilowattimme kostar under dagen. Där ingår skatt, avgifter och moms. Elnät ingår om du har valt elnätsbolag.",
                    "Tryck i grafen för att se priset vid en viss tid."
                ]
            )

            PriceChartPlot(
                day: payload.day,
                profile: costProfile
            )
        }
    }
}

private struct PriceChartPlot: View {
    let day: DayChartData
    let profile: CostProfile

    var body: some View {
        PriceChartCanvas(
            series: TotalPriceChartSeries(day: day, profile: profile),
            day: day,
            profile: profile
        )
    }
}

private struct PriceChartCanvas: View {
    let series: TotalPriceChartSeries
    let day: DayChartData
    let profile: CostProfile
    @State private var selectedChartDate: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            chart(now: context.date)
        }
    }

    private func currentPoint(at now: Date) -> TotalPriceChartPoint? {
        guard let bucket = day.currentBucket(at: now) else { return nil }
        return series.points.first { $0.start == bucket.start } ?? series.point(nearestTo: bucket.start)
    }

    private func nowPriceLabel(_ price: Double) -> String {
        "Nu \(AppFormatters.kr(price, fractionLength: 2))"
    }

    private func nowPriceAccessibilityLabel(_ price: Double) -> String {
        let amount = price.formatted(.number.precision(.fractionLength(2)))
        return "Nuvarande pris, \(amount) kronor per kilowattimme"
    }

    private func chart(now: Date) -> some View {
        let current = currentPoint(at: now)
        let selectedPoint = selectedChartDate.flatMap { series.point(nearestTo: $0) }
        let selectionIsCurrent = selectedPoint != nil && selectedPoint?.start == current?.start

        return Chart {
            ForEach(series.points) { point in
                LineMark(
                    x: .value("Tid", point.start),
                    y: .value("kr/kWh", point.price),
                    series: .value("Pris", "Total")
                )
                .foregroundStyle(series.lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if let current {
                RuleMark(x: .value("Nu", current.start))
                    .foregroundStyle(.primary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .accessibilityLabel(nowPriceAccessibilityLabel(current.price))

                PointMark(
                    x: .value("Nu", current.start),
                    y: .value("kr/kWh", current.price)
                )
                .foregroundStyle(current.color)
                .symbolSize(selectionIsCurrent ? 90 : 70)
                .accessibilityHidden(true)

                if !selectionIsCurrent {
                    PointMark(
                        x: .value("Nu", current.start),
                        y: .value("kr/kWh", current.price)
                    )
                    .opacity(0)
                    .annotation(position: .top, alignment: .leading, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.fitToPlot) {
                        ChartValueCallout(value: nowPriceLabel(current.price))
                    }
                    .accessibilityHidden(true)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Vald tid", selectedPoint.start))
                    .foregroundStyle(DS.Color.secondary.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: selectionIsCurrent ? [4, 3] : []))
                    .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: ChartCalloutOverflow.resolution) {
                        PriceChartSelectionCallout(
                            point: selectedPoint,
                            day: day,
                            profile: profile
                        )
                    }

                if !selectionIsCurrent {
                    PointMark(
                        x: .value("Vald tid", selectedPoint.start),
                        y: .value("kr/kWh", selectedPoint.price)
                    )
                    .foregroundStyle(selectedPoint.color)
                    .symbolSize(70)
                }
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
        .chartPlotStyle { plot in
            plot.padding(.top, DS.Spacing.sm)
        }
        .spriceChartMotion(series.points.map(\.price), selectedChartDate, current?.start)
        .frame(height: 260)
        .padding(DS.Spacing.card)
        .spriceCard(tone: .price)
        .zIndex(1)
        .accessibilityHint("Dra över grafen för att se pris vid en viss tid.")
    }
}

private struct PriceChartSelectionCallout: View {
    let point: TotalPriceChartPoint
    let day: DayChartData
    let profile: CostProfile

    var body: some View {
        ChartCalloutView(
            bucket: point.bucket,
            dayData: day,
            profile: profile,
            style: .opaque
        )
    }
}

private struct MarketContractExplanation: View {
    let profile: CostProfile

    private let totalCostService = TotalCostService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Så beräknas priset",
                paragraphs: [explanationText]
            )

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
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .price)
    }

    private var explanationText: String {
        switch profile.retailContractType {
        case .spotPriceMarkup:
            return "Grafen visar vad en kWh kostar under dagen. Där ingår spotpris, påslag, skatt, avgifter och moms. Elnät ingår om du har valt elnätsbolag."
        case .variableMonthlyPrice:
            return "Grafen visar vad en kWh kostar under dagen. Elhandeln räknas från ditt rörliga månadspris, inte från kvartens spotpris. Skatt, avgifter och moms ingår. Elnät ingår om du har valt elnätsbolag."
        case .fixedPrice:
            return "Grafen visar vad en kWh kostar under dagen. Elhandeln räknas från ditt fasta avtalade pris, inte från kvartens spotpris. Skatt, avgifter och moms ingår. Elnät ingår om du har valt elnätsbolag."
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

        if baseCost.vatKr > 0 {
            rows.append(("Moms", baseCost.vatKr))
        }

        return rows
    }
}
