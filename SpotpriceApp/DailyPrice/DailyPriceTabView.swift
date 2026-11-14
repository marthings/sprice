import SwiftUI
import Charts
import Accessibility

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
                    "Kurvan visar vad en kilowattimme kostar under dagen, med skatt, avgifter och moms. Elnätet ingår om du har valt elnätsbolag.",
                    "Tryck i grafen för att se priset vid en viss tid."
                ]
            )

            PriceAnswerLine(series: series)

            PriceChartPlot(
                day: payload.day,
                profile: costProfile
            )
        }
    }

    private var series: TotalPriceChartSeries {
        TotalPriceChartSeries(day: payload.day, profile: costProfile)
    }
}

/// Answers the question people open the tab with: when is it cheapest?
private struct PriceAnswerLine: View {
    let series: TotalPriceChartSeries

    var body: some View {
        let lines = series.answerLines
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

extension TotalPriceChartSeries {
    var cheapestPoint: TotalPriceChartPoint? { points.min { $0.price < $1.price } }
    var dearestPoint: TotalPriceChartPoint? { points.max { $0.price < $1.price } }

    /// "Billigast runt kl. 03 och dyrast runt kl. 18." The prices are in Prisspann right below.
    var answerLines: [String] {
        guard let cheapest = cheapestPoint, let dearest = dearestPoint, cheapest.start != dearest.start else {
            return []
        }
        return [
            "Billigast runt kl. \(Self.hourLabel(cheapest.start)) och dyrast runt kl. \(Self.hourLabel(dearest.start))."
        ]
    }

    /// For VoiceOver, with the prices, since the chart itself is not visible.
    var answerText: String? {
        guard let cheapest = cheapestPoint, let dearest = dearestPoint, cheapest.start != dearest.start else {
            return nil
        }
        return "Billigast runt kl. \(Self.hourLabel(cheapest.start)), \(AppFormatters.krPerKWh(cheapest.price)). Dyrast runt kl. \(Self.hourLabel(dearest.start)), \(AppFormatters.krPerKWh(dearest.price))."
    }

    static func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).locale(AppFormatters.swedishLocale))
    }

    /// Stretches of the day where the price is in the cheapest quarter of the day's range.
    /// Empty when the day is almost flat, since highlighting everything says nothing.
    var cheapRuns: [(start: Date, end: Date)] {
        guard let low = points.map(\.price).min(), let high = points.map(\.price).max(), high - low >= 0.2 else {
            return []
        }
        let limit = low + (high - low) * 0.25
        var runs: [(start: Date, end: Date)] = []
        var current: (start: Date, end: Date)?
        for point in points {
            if point.price <= limit {
                if let existing = current, existing.end == point.bucket.start {
                    current = (existing.start, point.bucket.end)
                } else {
                    if let finished = current { runs.append(finished) }
                    current = (point.bucket.start, point.bucket.end)
                }
            } else if let finished = current {
                runs.append(finished)
                current = nil
            }
        }
        if let finished = current { runs.append(finished) }
        return runs
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
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 260
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

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
        "Nu \(AppFormatters.krPerKWh(price))"
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
            ForEach(Array(series.cheapRuns.enumerated()), id: \.offset) { _, run in
                RectangleMark(
                    xStart: .value("Billigt från", run.start),
                    xEnd: .value("Billigt till", run.end),
                    yStart: .value("kr/kWh", series.yDomain.lowerBound),
                    yEnd: .value("kr/kWh", series.yDomain.upperBound)
                )
                .foregroundStyle(DS.Color.success.opacity(differentiateWithoutColor ? 0.2 : 0.09))
                .accessibilityHidden(true)
            }

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
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisTick(length: 0)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.hour()))
                            .font(DS.Font.footnote)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisTick(length: 0)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.footnote)
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
        .frame(height: chartHeight)
        .padding(DS.Spacing.card)
        .spriceCard(tone: .price)
        .zIndex(1)
        .accessibilityChartDescriptor(PriceChartDescriptor(series: series, current: current))
        .accessibilityHint("Svep uppåt eller nedåt för att gå timme för timme.")
        .accessibilityValue(selectedPoint.map { Self.spokenPrice($0) } ?? "")
        .accessibilityAdjustableAction { direction in
            stepSelection(direction, current: current)
        }
    }

    /// Lets VoiceOver users move the selected hour with swipe up and down,
    /// since dragging a finger across the chart is not possible for them.
    private func stepSelection(_ direction: AccessibilityAdjustmentDirection, current: TotalPriceChartPoint?) {
        let hours = series.hourlyPoints
        guard !hours.isEmpty else { return }
        let reference = selectedChartDate ?? current?.start ?? hours[0].start
        let index = hours.indices.min { lhs, rhs in
            abs(hours[lhs].start.timeIntervalSince(reference)) < abs(hours[rhs].start.timeIntervalSince(reference))
        } ?? 0
        let next: Int
        switch direction {
        case .increment: next = min(index + 1, hours.count - 1)
        case .decrement: next = max(index - 1, 0)
        @unknown default: next = index
        }
        selectedChartDate = hours[next].start
    }

    private static func spokenPrice(_ point: TotalPriceChartPoint) -> String {
        let hour = point.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale))
        let amount = point.price.formatted(.number.precision(.fractionLength(2)))
        return "Klockan \(hour), \(amount) kronor per kilowattimme"
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
                title: "Så räknas priset",
                paragraphs: [explanationText]
            )

            SpriceDisclosure(
                title: "Visa de fasta delarna",
                openTitle: "Dölj de fasta delarna",
                accessibilityName: "Fasta delar i priset"
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(staticCostRows, id: \.title) { row in
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(row.title)
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                                Spacer(minLength: DS.Spacing.sm)
                                Text(AppFormatters.krPerKWh(row.value))
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(.primary)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.title)
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                                Text(AppFormatters.krPerKWh(row.value))
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityElement(children: .combine)
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
            return "Priset i grafen är spotpriset plus påslag, skatt, avgifter och moms. Spotpriset rör sig under dagen, de fasta delarna ligger still. Elnätet ingår om du har valt elnätsbolag."
        case .variableMonthlyPrice:
            return "Elhandeln räknas från ditt rörliga månadspris, inte från spotpriset. Skatt, avgifter och moms ingår, och elnätet om du har valt elnätsbolag."
        case .fixedPrice:
            return "Elhandeln räknas från ditt fasta pris, inte från spotpriset. Skatt, avgifter och moms ingår, och elnätet om du har valt elnätsbolag."
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
                rows.append(("Elhandlarens påslag", retailFees))
            }
        case .variableMonthlyPrice, .fixedPrice:
            if baseCost.spotCostKr > 0 {
                rows.append((profile.retailContractDisplayName, baseCost.spotCostKr))
            }
            if baseCost.providerMonthlyFeeKr > 0 {
                rows.append(("Elhandlarens månadsavgift", baseCost.providerMonthlyFeeKr))
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

extension TotalPriceChartSeries {
    /// One point per whole hour, for stepping with VoiceOver.
    var hourlyPoints: [TotalPriceChartPoint] {
        let calendar = Calendar.energyHistory
        return points.filter { calendar.component(.minute, from: $0.start) == 0 }
    }
}

/// Gives VoiceOver users a summary and Apple's audio graph for the price curve.
private struct PriceChartDescriptor: AXChartDescriptorRepresentable {
    let series: TotalPriceChartSeries
    let current: TotalPriceChartPoint?

    func makeChartDescriptor() -> AXChartDescriptor {
        let points = series.points
        let hourLabels = points.map {
            $0.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale))
        }
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Klockslag",
            categoryOrder: hourLabels
        )
        let prices = points.map(\.price)
        let lower = prices.min() ?? 0
        let upper = max(prices.max() ?? 1, lower + 0.01)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Kronor per kilowattimme",
            range: lower...upper,
            gridlinePositions: []
        ) { value in
            "\(value.formatted(.number.precision(.fractionLength(2)))) kronor per kilowattimme"
        }
        let dataPoints = zip(hourLabels, prices).map { label, price in
            AXDataPoint(x: label, y: price)
        }
        let dataSeries = AXDataSeriesDescriptor(
            name: "Totalpris per kilowattimme",
            isContinuous: true,
            dataPoints: dataPoints
        )
        var summaryParts: [String] = []
        if let text = series.answerText { summaryParts.append(text) }
        if let current {
            summaryParts.append("Nu \(AppFormatters.krPerKWh(current.price)).")
        }
        return AXChartDescriptor(
            title: "Dagens totalpris",
            summary: summaryParts.joined(separator: " "),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [dataSeries]
        )
    }
}
