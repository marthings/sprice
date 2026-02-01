//
//  SpotPriceBarChart.swift
//  Spotprice
//

import SwiftUI
import Charts

struct SpotPriceBarChart: View {
    let dayData: DayChartData
    let configuration: ChartConfiguration
    @State private var selectedDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            chartHeader
                .padding(.horizontal)
            chartContent
        }
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        let now = Date()
        let currentBucket = dayData.buckets.first { $0.start <= now && $0.end > now }
        let currentPrice = currentBucket?.orePerKWh

        // Find next quarter's bucket (15 minutes)
        let currentBucketEnd = currentBucket?.end ?? now
        let nextBucket = dayData.buckets.first { $0.start >= currentBucketEnd }
        let nextPrice = nextBucket?.orePerKWh

        return HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let price = currentPrice {
                    // Price with accessible category badge
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        Text("\(Int(price.rounded()))")
                            .font(DS.Font.bold(30).monospacedDigit())
                            .foregroundStyle(priceColor(for: price))
                        Text("öre/kWh")
                            .font(DS.Font.medium(11))
                            .foregroundStyle(.secondary)
                    }

                    
                } else {
                    Text("–")
                        .font(DS.Font.bold(20))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text("Nästa kvart")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)

                if let next = nextPrice, let current = currentPrice {
                    HStack(spacing: DS.Spacing.xs) {
                        TrendIndicator(current: current, next: next)
                        Text("\(Int(next.rounded()))")
                            .font(DS.Font.semibold(12).monospacedDigit())
                            .foregroundStyle(priceColor(for: next))
                    }
                } else if let next = nextPrice {
                    Text("\(Int(next.rounded()))")
                        .font(DS.Font.semibold(12).monospacedDigit())
                        .foregroundStyle(priceColor(for: next))
                } else {
                    Text("–")
                        .font(DS.Font.semibold(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        Chart {
            // Area fill
            ForEach(dayData.buckets) { bucket in
                AreaMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(areaGradient)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.3)
            }

            // Line with gradient coloring
            LineMark(
                x: .value("Tid", dayData.buckets.first?.start ?? Date()),
                y: .value("Pris", dayData.buckets.first?.orePerKWh ?? 0),
                series: .value("Price", "A")
            )
            .foregroundStyle(lineGradient)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            ForEach(dayData.buckets.dropFirst()) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh),
                    series: .value("Price", "A")
                )
                .foregroundStyle(lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.4)
            }

            // Selected point
            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                PointMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(priceColor(for: bucket.orePerKWh))
                .symbolSize(64)
                .symbol(.circle)
            }

            // Current time indicator
            if let now = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) {
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
                        ChartCalloutView(bucket: bucket, dayData: dayData)
                    }
            }
        }
        .chartXScale(domain: calendarBounds(for: dayData.buckets.first?.start))
        .chartYScale(domain: 0...max(dayData.maxOre * 1.1, dayData.minOre + 10))
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            if configuration.showXAxisLabels {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.hour()))
                                .font(DS.Font.micro)
                                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text("\(Int(price.rounded()))")
                                .font(DS.Font.micro)
                                .foregroundStyle(.secondary)
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
        LinearGradient(
            colors: [
                DS.Color.warning.opacity(0.3),
                DS.Color.warning.opacity(0.1),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
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

    // MARK: - Helper Methods

    private func priceColor(for price: Double) -> Color {
        DS.Color.forPrice(price, min: dayData.minOre, max: dayData.maxOre)
    }

    private func calendarBounds(for date: Date?) -> ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: date ?? Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
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
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let hourProgress = location.x / 300
        let selectedHour = Int(hourProgress * 24)

        if let selectedDate = Calendar.current.date(byAdding: .hour, value: selectedHour, to: startOfDay) {
            self.selectedDate = selectedDate
        }
    }
}
