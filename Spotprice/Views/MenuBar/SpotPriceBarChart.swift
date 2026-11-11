//
//  SpotPriceBarChart.swift
//  Spotprice
//

import SwiftUI
import Charts

struct SpotPriceBarChart: View {
    let dayData: DayChartData
    let costProfile: CostProfile
    let configuration: ChartConfiguration
    var tariff: SimplifiedTariff? = nil

    @State private var selectedDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            SpotPriceBarChartHeader(dayData: dayData, costProfile: costProfile)
                .padding(.horizontal)
            SpotPriceBarChartPlot(
                dayData: dayData,
                configuration: configuration,
                costProfile: costProfile,
                selectedDate: $selectedDate
            )
        }
    }
}

private struct SpotPriceBarChartStyle {
    let areaGradient: LinearGradient
    let lineGradient: LinearGradient
    let maxY: Double

    init(dayData: DayChartData) {
        let colors = dayData.buckets.map {
            DS.Color.forPrice($0.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
        }
        lineGradient = LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        areaGradient = LinearGradient(
            colors: colors.map { $0.opacity(0.26) },
            startPoint: .leading,
            endPoint: .trailing
        )
        maxY = dayData.maxOre * 1.1
    }
}

private struct SpotPriceBarChartHeader: View {
    let dayData: DayChartData
    let costProfile: CostProfile

    private let totalCostService = TotalCostService.shared
    private let totalCostBounds: (min: Double, max: Double)?

    init(dayData: DayChartData, costProfile: CostProfile) {
        self.dayData = dayData
        self.costProfile = costProfile

        if costProfile.isSpotFollowingRetailContract {
            let service = TotalCostService.shared
            let costs = dayData.buckets.map {
                service.calculatePricePerKWh(spotPriceOre: $0.orePerKWh, profile: costProfile) * 100
            }
            totalCostBounds = (costs.min() ?? 0, costs.max() ?? 0)
        } else {
            totalCostBounds = nil
        }
    }

    var body: some View {
        let now = Date.now
        let currentBucket = dayData.buckets.first { $0.start <= now && $0.end > now }
        let currentPrice = currentBucket?.orePerKWh
        let currentBucketEnd = currentBucket?.end ?? now
        let nextBucket = dayData.buckets.first { $0.start >= currentBucketEnd }
        let nextPrice = nextBucket?.orePerKWh

        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let price = currentPrice {
                    let value = primaryHeaderValue(for: price)

                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(value.amount, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.fixed(30).monospacedDigit())
                            .foregroundStyle(value.color)
                            .spriceNumericText(value.amount)
                        Text(value.unit)
                            .font(DS.Font.medium(11))
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else {
                    Text("–")
                        .font(DS.Font.bold(20))
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text("Nästa kvart")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)

                if let next = nextPrice, let current = currentPrice {
                    let nextValue = nextQuarterValue(for: next)

                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: current, next: next)
                        Text(nextValue.amount, format: .number.precision(.fractionLength(nextValue.decimals)))
                            .font(DS.Font.semibold(12).monospacedDigit())
                            .foregroundStyle(nextValue.color)
                        Text(nextValue.unit)
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else if let next = nextPrice {
                    let nextValue = nextQuarterValue(for: next)

                    HStack(spacing: DS.Spacing.xxs) {
                        Text(nextValue.amount, format: .number.precision(.fractionLength(nextValue.decimals)))
                            .font(DS.Font.semibold(12).monospacedDigit())
                            .foregroundStyle(nextValue.color)
                        Text(nextValue.unit)
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else {
                    Text("–")
                        .font(DS.Font.semibold(12))
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            SectionInfoButton(
                title: "grafen",
                paragraphs: [chartMeaningText]
            )
        }
        .padding(.top, DS.Spacing.card)
        .padding(.bottom, DS.Spacing.cardContent)
    }

    private var chartMeaningText: String {
        if costProfile.isSpotFollowingRetailContract {
            return "Grafen visar marknadens kvartspris och din beräknade kostnad följer variationen."
        }
        return "Grafen visar marknadens kvartspris. Din kostnad beräknas från ditt avtal."
    }

    private func primaryHeaderValue(for marketPriceOre: Double) -> (amount: Double, unit: String, color: Color) {
        if costProfile.isSpotFollowingRetailContract {
            let totalCost = totalCostService.calculatePricePerKWh(spotPriceOre: marketPriceOre, profile: costProfile)
            return (totalCost, "kr/kWh", totalCostColor(for: totalCost * 100))
        }
        return (marketPriceOre / 100, "kr/kWh", DS.Color.forPrice(marketPriceOre, min: dayData.minOre, max: dayData.maxOre))
    }

    private func nextQuarterValue(for marketPriceOre: Double) -> (amount: Double, unit: String, color: Color, decimals: Int) {
        if costProfile.isSpotFollowingRetailContract {
            let totalCost = totalCostService.calculatePricePerKWh(spotPriceOre: marketPriceOre, profile: costProfile)
            return (totalCost, "kr", totalCostColor(for: totalCost * 100), 2)
        }
        return (
            marketPriceOre / 100,
            "kr",
            DS.Color.forPrice(marketPriceOre, min: dayData.minOre, max: dayData.maxOre),
            2
        )
    }

    private func totalCostColor(for totalCost: Double) -> Color {
        guard let totalCostBounds else {
            return DS.Color.forPrice(totalCost, min: dayData.minOre, max: dayData.maxOre)
        }
        return DS.Color.forPrice(totalCost, min: totalCostBounds.min, max: totalCostBounds.max)
    }
}

private struct SpotPriceBarChartPlot: View {
    let dayData: DayChartData
    let configuration: ChartConfiguration
    let costProfile: CostProfile
    @Binding var selectedDate: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            plot(now: context.date)
        }
    }

    private func nowPriceLabel(for orePerKWh: Double) -> String {
        "Nu \(AppFormatters.kr(orePerKWh / 100, fractionLength: 2))"
    }

    private func nowPriceAccessibilityLabel(for orePerKWh: Double) -> String {
        let amount = (orePerKWh / 100).formatted(.number.precision(.fractionLength(2)))
        return "Nuvarande pris, \(amount) kronor per kilowattimme"
    }

    private func plot(now: Date) -> some View {
        let style = SpotPriceBarChartStyle(dayData: dayData)
        let currentBucket = dayData.currentBucket(at: now)
        let selectedBucket = selectedDate.flatMap { findBucket(for: $0, in: dayData.buckets) }
        let selectionIsCurrent = selectedBucket != nil && selectedBucket?.start == currentBucket?.start

        return Chart {
            ForEach(dayData.buckets) { bucket in
                AreaMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh)
                )
                .foregroundStyle(style.areaGradient)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.3)
            }

            LineMark(
                x: .value("Tid", dayData.buckets.first?.start ?? Date.now),
                y: .value("Kvartspris", dayData.buckets.first?.orePerKWh ?? 0),
                series: .value("Price", "Market")
            )
            .foregroundStyle(style.lineGradient)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            ForEach(dayData.buckets.dropFirst()) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh),
                    series: .value("Price", "Market")
                )
                .foregroundStyle(style.lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.4)
            }

            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets), !selectionIsCurrent {
                PointMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh)
                )
                .foregroundStyle(DS.Color.forPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre))
                .symbolSize(64)
                .symbol(.circle)
            }

            if !costProfile.isSpotFollowingRetailContract, let contractPrice = costProfile.contractPriceOrePerKWh {
                RuleMark(y: .value("Avtalat pris", contractPrice))
                    .foregroundStyle(.blue.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .annotation(position: .top, alignment: .trailing, overflowResolution: ChartCalloutOverflow.resolution) {
                        Text("Ditt avtal: \((contractPrice / 100).formatted(.number.precision(.fractionLength(2)))) kr/kWh")
                            .font(DS.Font.footnote)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(.blue.opacity(0.1), in: .capsule)
                    }
                    .accessibilityLabel("Avtalat elpris")
            }

            if let currentBucket {
                RuleMark(x: .value("Nu", currentBucket.start))
                    .foregroundStyle(.primary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .accessibilityLabel(nowPriceAccessibilityLabel(for: currentBucket.orePerKWh))

                PointMark(
                    x: .value("Nu", currentBucket.start),
                    y: .value("Kvartspris", currentBucket.orePerKWh)
                )
                .foregroundStyle(DS.Color.forPrice(currentBucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre))
                .symbolSize(selectionIsCurrent ? 90 : 64)
                .symbol(.circle)
                .accessibilityHidden(true)

                if !selectionIsCurrent {
                    PointMark(
                        x: .value("Nu", currentBucket.start),
                        y: .value("Kvartspris", currentBucket.orePerKWh)
                    )
                    .opacity(0)
                    .annotation(position: .top, alignment: .leading, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.fitToPlot) {
                        ChartValueCallout(value: nowPriceLabel(for: currentBucket.orePerKWh))
                    }
                    .accessibilityHidden(true)
                }
            }

            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: ChartCalloutOverflow.resolution) {
                        ChartCalloutView(bucket: bucket, dayData: dayData, profile: costProfile)
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartYScale(domain: 0...style.maxY)
        .chartXSelection(value: $selectedDate)
        .chartPlotStyle { plot in
            plot.padding(.top, DS.Spacing.sm)
        }
        .chartXAxis {
            if configuration.showXAxisLabels {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(DS.Color.secondary)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.hour()))
                                .font(DS.Font.footnote)
                                .foregroundStyle(DS.Color.secondary)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            if configuration.showYAxisLabels {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(DS.Color.secondary)
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text((price / 100), format: .number.precision(.fractionLength(2)))
                                .font(DS.Font.footnote)
                                .foregroundStyle(DS.Color.secondary)
                        }
                    }
                }
            }
        }
        .spriceChartMotion(dayData.buckets.map(\.orePerKWh), selectedDate, currentBucket?.start)
        .frame(height: configuration.height)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }

    private func calendarBounds(for date: Date?) -> ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: date ?? Date.now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return start...end
    }

    private func findBucket(for date: Date, in buckets: [PriceBucket]) -> PriceBucket? {
        buckets.first { $0.start <= date && $0.end > date }
    }

    private func isBucketSelected(_ bucket: PriceBucket, selectedDate: Date?) -> Bool {
        guard let selectedDate else { return true }
        return bucket.start <= selectedDate && bucket.end > selectedDate
    }
}