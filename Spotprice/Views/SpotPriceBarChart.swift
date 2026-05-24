//
//  SpotPriceBarChart.swift
//  Spotprice
//

import SwiftUI
import Charts

struct SpotPriceBarChart: View {
    let dayData: DayChartData
    let configuration: ChartConfiguration
    var tariff: SimplifiedTariff? = nil
    @State private var selectedDate: Date?
    private let totalCostService = TotalCostService()

    private var costProfile: CostProfile {
        ConsumptionSettings.shared.costProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            chartHeader
                .padding(.horizontal)
            chartContent
        }
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        let now = Date.now
        let currentBucket = dayData.buckets.first { $0.start <= now && $0.end > now }
        let currentPrice = currentBucket?.orePerKWh

        // Find next quarter's bucket (15 minutes)
        let currentBucketEnd = currentBucket?.end ?? now
        let nextBucket = dayData.buckets.first { $0.start >= currentBucketEnd }
        let nextPrice = nextBucket?.orePerKWh

        return HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let price = currentPrice {
                    let value = primaryHeaderValue(for: price)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                            Text(value.amount, format: .number.precision(.fractionLength(2)))
                                .font(DS.Font.bold(30).monospacedDigit())
                                .foregroundStyle(value.color)
                            Text(value.unit)
                                .font(DS.Font.medium(11))
                                .foregroundStyle(DS.Color.secondary)
                            if let label = costProfile.confidence.menuBarLabel {
                                Text(label)
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }

                        Text(chartMeaningText)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else {
                    Text("–")
                        .font(DS.Font.bold(20))
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text("Nästa kvart")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)

                if let next = nextPrice, let current = currentPrice {
                    let nextValue = nextQuarterValue(for: next)
                    
                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: current, next: next)
                        Text(nextValue.amount, format: .number.precision(.fractionLength(nextValue.decimals)))
                            .font(DS.Font.semibold(12).monospacedDigit())
                            .foregroundStyle(nextValue.color)
                        Text(nextValue.unit)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else if let next = nextPrice {
                    let nextValue = nextQuarterValue(for: next)
                    
                    HStack(spacing: DS.Spacing.xxs) {
                        Text(nextValue.amount, format: .number.precision(.fractionLength(nextValue.decimals)))
                            .font(DS.Font.semibold(12).monospacedDigit())
                            .foregroundStyle(nextValue.color)
                        Text(nextValue.unit)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                } else {
                    Text("–")
                        .font(DS.Font.semibold(12))
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        Chart {
            ForEach(dayData.buckets) { bucket in
                AreaMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh)
                )
                .foregroundStyle(areaGradient)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.3)
            }

            LineMark(
                x: .value("Tid", dayData.buckets.first?.start ?? Date.now),
                y: .value("Kvartspris", dayData.buckets.first?.orePerKWh ?? 0),
                series: .value("Price", "Market")
            )
            .foregroundStyle(lineGradient)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            ForEach(dayData.buckets.dropFirst()) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh),
                    series: .value("Price", "Market")
                )
                .foregroundStyle(lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.4)
            }

            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                PointMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Kvartspris", bucket.orePerKWh)
                )
                .foregroundStyle(priceColor(for: bucket.orePerKWh))
                .symbolSize(64)
                .symbol(.circle)
            }

            // Contract reference line for fixed and variable contracts
            if !costProfile.isSpotFollowingRetailContract, let contractPrice = costProfile.contractPriceOrePerKWh {
                RuleMark(y: .value("Avtalat pris", contractPrice))
                    .foregroundStyle(.blue.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ditt avtal: \(Int(contractPrice.rounded())) öre/kWh")
                            .font(DS.Font.micro)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(.blue.opacity(0.1), in: .capsule)
                    }
                    .accessibilityLabel("Avtalat elpris")
            }

            // Current time indicator
            if let now = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date.now), minute: 0, second: 0, of: Date.now) {
                RuleMark(x: .value("Nu", now))
                    .foregroundStyle(.primary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .accessibilityLabel("Nuvarande tid")
            }

            // Selection indicator with callout
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                        ChartCalloutView(bucket: bucket, dayData: dayData, profile: costProfile)
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartYScale(domain: 0...maxYValue())
        .chartXSelection(value: $selectedDate)
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
                                .font(DS.Font.micro)
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
                            Text("\(Int(price.rounded()))")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: configuration.height)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.15)) {
                        updateSelection(at: value.location)
                    }
                }
        )
    }

    // MARK: - Gradients

    private var areaGradient: LinearGradient {
        let colors = dayData.buckets.map { priceColor(for: $0.orePerKWh).opacity(0.26) }
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var lineGradient: LinearGradient {
        let colors = dayData.buckets.map { priceColor(for: $0.orePerKWh) }
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var totalCostGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.3),
                Color.blue.opacity(0.1),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var totalCostLineGradient: LinearGradient {
        let totalCosts = dayData.buckets.map { totalCostOre(for: $0.orePerKWh) }
        let minTotal = totalCosts.min() ?? 0
        let maxTotal = totalCosts.max() ?? 0
        let colors = totalCosts.map { totalCostColor(for: $0, min: minTotal, max: maxTotal) }
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Helper Methods

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
        return (marketPriceOre, "öre/kWh", priceColor(for: marketPriceOre))
    }
    
    private func nextQuarterValue(for marketPriceOre: Double) -> (amount: Double, unit: String, color: Color, decimals: Int) {
        if costProfile.isSpotFollowingRetailContract {
            let totalCost = totalCostService.calculatePricePerKWh(spotPriceOre: marketPriceOre, profile: costProfile)
            return (totalCost, "kr", totalCostColor(for: totalCost * 100), 2)
        }
        return (marketPriceOre, "öre", priceColor(for: marketPriceOre), 0)
    }
    
    private func currentQuarterValue(for marketPriceOre: Double) -> (amount: Double, unit: String, color: Color, decimals: Int) {
        nextQuarterValue(for: marketPriceOre)
    }

    private func priceColor(for price: Double) -> Color {
        DS.Color.forPrice(price, min: dayData.minOre, max: dayData.maxOre)
    }
    
    private func totalCostOre(for spotPriceOre: Double) -> Double {
        totalCostService.calculatePricePerKWh(spotPriceOre: spotPriceOre, profile: costProfile) * 100
    }

    private func totalCostColor(for totalCost: Double) -> Color {
        let totalCosts = dayData.buckets.map { totalCostOre(for: $0.orePerKWh) }
        let minTotal = totalCosts.min() ?? 0
        let maxTotal = totalCosts.max() ?? 0
        return totalCostColor(for: totalCost, min: minTotal, max: maxTotal)
    }
    
    private func totalCostColor(for totalCost: Double, min: Double, max: Double) -> Color {
        DS.Color.forPrice(totalCost, min: min, max: max)
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

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
    }

    private func updateSelection(at location: CGPoint) {
        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        let hourProgress = location.x / 300
        let selectedHour = Int(hourProgress * 24)

        if let selectedDate = Calendar.current.date(byAdding: .hour, value: selectedHour, to: startOfDay) {
            self.selectedDate = selectedDate
        }
    }
    
    private func maxYValue() -> Double {
        dayData.maxOre * 1.1
    }
}
