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
    @State private var hoveredBucket: PriceBucket?

    var body: some View {
        VStack(spacing: 0) {
            chartHeader
                .padding(.horizontal)
            chartContent
        }
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pris nu")
                    .font(.custom("Avenir", size: 12).weight(.medium))
                    .foregroundStyle(.secondary)

                if let current = currentPriceBucket {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int(current.orePerKWh.rounded()))")
                            .font(.custom("Avenir", size: 20).weight(.bold).monospacedDigit())
                            .foregroundStyle(current.category.color)
                        Text("öre/kWh")
                            .font(.custom("Avenir", size: 11).weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Nästa")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)

                if let next = nextPriceBucket {
                    HStack(spacing: 4) {
                        PriceChangeIndicator(current: currentPriceBucket?.orePerKWh, next: next.orePerKWh)
                        Text("\(Int(next.orePerKWh.rounded()))")
                            .font(.custom("Avenir", size: 12).weight(.semibold).monospacedDigit())
                            .foregroundStyle(next.category.color)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        Chart {
            ForEach(dayData.buckets) { bucket in
                AreaMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            dynamicGradientColor(for: bucket).opacity(0.4),
                            dynamicGradientColor(for: bucket).opacity(0.1),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.3)
            }

            ForEach(dayData.buckets) { bucket in
                LineMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(dynamicGradientColor(for: bucket))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .opacity(selectedDate == nil || isBucketSelected(bucket, selectedDate: selectedDate) ? 1.0 : 0.4)
                .accessibilityLabel("Pris \(Int(bucket.orePerKWh.rounded())) öre per kWh klockan \(timeLabel(bucket.start))")
                .accessibilityValue("\(bucket.category.description)")
            }

            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                PointMark(
                    x: .value("Tid", bucket.start),
                    y: .value("Pris", bucket.orePerKWh)
                )
                .foregroundStyle(dynamicGradientColor(for: bucket))
                .symbolSize(64)
                .symbol(.circle)
            }

            if let now = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) {
                RuleMark(x: .value("Nu", now))
                    .foregroundStyle(.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .accessibilityLabel("Nuvarande tid")
            }

            if let selectedDate, let bucket = findBucket(for: selectedDate, in: dayData.buckets) {
                RuleMark(x: .value("Vald tid", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit, y: .disabled)) {
                        ChartCalloutView(bucket: bucket)
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
                        .foregroundStyle(.quaternary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.hour()))
                                .font(.custom("Avenir", size: 10).weight(.medium))
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
                        .foregroundStyle(.quaternary)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text("\(Int(price.rounded()))")
                                .font(.custom("Avenir", size: 10).weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: configuration.height)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.2)) {
                        updateSelection(at: value.location)
                    }
                }
        )
    }

    // MARK: - Computed Properties

    private var currentPriceBucket: PriceBucket? {
        let now = Date()
        return dayData.buckets.first { $0.start <= now && $0.end > now }
    }

    private var nextPriceBucket: PriceBucket? {
        let now = Date()
        return dayData.buckets.first { $0.start > now }
    }

    // MARK: - Helper Methods

    private func dynamicGradientColor(for bucket: PriceBucket) -> Color {
        let normalizedPrice = (bucket.orePerKWh - dayData.minOre) / (dayData.maxOre - dayData.minOre)

        if normalizedPrice <= 0.33 {
            return Color.green.interpolated(to: .yellow, by: normalizedPrice * 3)
        } else if normalizedPrice <= 0.66 {
            return Color.yellow.interpolated(to: .orange, by: (normalizedPrice - 0.33) * 3)
        } else {
            return Color.orange.interpolated(to: .red, by: (normalizedPrice - 0.66) * 3)
        }
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
