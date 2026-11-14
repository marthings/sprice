//
//  ChartConfiguration.swift
//  Spotprice
//

import SwiftUI
import Charts

enum ChartCalloutOverflow {
    /// Keeps selection callouts inside the chart horizontally, and lets them
    /// draw above the plot instead of being clipped by the card.
    static var resolution: AnnotationOverflowResolution {
        AnnotationOverflowResolution(x: .fit(to: .chart), y: .disabled)
    }

    /// Keeps a label inside the plot so it cannot cover axis values,
    /// including wide ones like "Prognos: 3 847 kr".
    static var fitToPlot: AnnotationOverflowResolution {
        AnnotationOverflowResolution(x: .fit(to: .plot), y: .disabled)
    }
}

/// Shared x-axis air and tick density for Historik charts.
enum HistoryChartAxis {
    static let plotTopPadding: CGFloat = DS.Spacing.sm
    static let plotBottomPadding: CGFloat = DS.Spacing.md
    static let labelTopPadding: CGFloat = DS.Spacing.xs
    static let hourStrideHours = 6
    /// One chart style: hairline gridlines in `DS.Color.gridLine`, no ticks, labels in
    /// footnote secondary, bars with a 3 pt radius.
    static let gridStroke = StrokeStyle(lineWidth: 0.5)
    static let barRadius: CGFloat = 3
    static let clockHourMarks: [Double] = [0, 6, 12, 18]

    static func monthDayStride(dayCount: Int) -> Int {
        dayCount <= 10 ? 2 : 5
    }

    @ViewBuilder
    static func label(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
            .padding(.top, labelTopPadding)
    }

    @ViewBuilder
    static func dayLabel(_ date: Date) -> some View {
        label(date.formatted(.dateTime.day()))
    }

    @ViewBuilder
    static func hourLabel(_ date: Date) -> some View {
        label(date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted))))
    }

    @ViewBuilder
    static func clockHourLabel(_ hour: Double) -> some View {
        label("\(Int(hour.rounded()))")
    }
}

extension View {
    func historyChartPlotStyle() -> some View {
        chartPlotStyle { plot in
            plot
                .padding(.top, HistoryChartAxis.plotTopPadding)
                .padding(.bottom, HistoryChartAxis.plotBottomPadding)
        }
    }
}

enum ChartConfiguration {
    case menuBar
    case fullSize

    var height: CGFloat {
        switch self {
        case .menuBar: return DS.Size.chartHeightMenuBar
        case .fullSize: return DS.Size.chartHeightFull
        }
    }

    var showXAxisLabels: Bool { true }
    var showYAxisLabels: Bool { true }

    var cornerRadius: CGFloat {
        switch self {
        case .menuBar: return DS.Radius.sm
        case .fullSize: return DS.Radius.lg
        }
    }
}

struct TotalPriceChartPoint: Identifiable {
    let start: Date
    let price: Double
    let color: Color
    let bucket: PriceBucket

    var id: Date { start }
}

/// Precomputed chart inputs for the iOS total-price line chart.
struct TotalPriceChartSeries {
    let points: [TotalPriceChartPoint]
    let yDomain: ClosedRange<Double>
    let lineGradient: LinearGradient

    init(day: DayChartData, profile: CostProfile, service: TotalCostService = .shared) {
        let prices = day.buckets.map { service.calculatePricePerKWh(spotPriceOre: $0.orePerKWh, profile: profile) }
        let minValue = prices.min() ?? 0
        let maxValue = prices.max() ?? minValue
        yDomain = Self.yDomain(for: prices)
        lineGradient = Self.lineGradient(prices: prices, min: minValue, max: maxValue)
        points = zip(day.buckets, prices).map { bucket, price in
            TotalPriceChartPoint(
                start: bucket.start,
                price: price,
                color: Self.smoothPriceColor(for: price, min: minValue, max: maxValue),
                bucket: bucket
            )
        }
    }

    func point(nearestTo date: Date) -> TotalPriceChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
        }
    }

    private static func yDomain(for prices: [Double]) -> ClosedRange<Double> {
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return 0...1
        }

        if minPrice == maxPrice {
            let padding = max(abs(minPrice) * 0.1, 1)
            return (minPrice - padding)...(maxPrice + padding)
        }

        let padding = (maxPrice - minPrice) * 0.08
        return Swift.max(0, minPrice - padding)...(maxPrice + padding)
    }

    private static func lineGradient(prices: [Double], min minPrice: Double, max maxPrice: Double) -> LinearGradient {
        guard !prices.isEmpty else {
            return LinearGradient(
                colors: [DS.Color.warning],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        let lastIndex = Swift.max(prices.count - 1, 1)
        let stops = prices.enumerated().map { index, price in
            Gradient.Stop(
                color: smoothPriceColor(for: price, min: minPrice, max: maxPrice),
                location: Double(index) / Double(lastIndex)
            )
        }

        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The cheap, middle and expensive fills from the asset catalog (light values), so the
    /// line matches the price badges.
    private static let cheap = Color(red: 0x25 / 255, green: 0x93 / 255, blue: 0x6A / 255)
    private static let middle = Color(red: 0xE0 / 255, green: 0x7A / 255, blue: 0x1A / 255)
    private static let expensive = Color(red: 0xDE / 255, green: 0x4A / 255, blue: 0x3A / 255)

    private static func smoothPriceColor(for price: Double, min minPrice: Double, max maxPrice: Double) -> Color {
        let range = maxPrice - minPrice
        guard range > 0 else { return DS.Color.warning }

        let normalized = Swift.min(Swift.max((price - minPrice) / range, 0), 1)
        switch normalized {
        case ..<0.5:
            return interpolateColor(from: cheap, to: middle, progress: normalized / 0.5)
        default:
            return interpolateColor(from: middle, to: expensive, progress: (normalized - 0.5) / 0.5)
        }
    }

    private static func interpolateColor(from start: Color, to end: Color, progress: Double) -> Color {
        let clampedProgress = Float(Swift.min(Swift.max(progress, 0), 1))
        let startComponents = start.resolve(in: EnvironmentValues())
        let endComponents = end.resolve(in: EnvironmentValues())

        return Color(
            red: Double(startComponents.red + ((endComponents.red - startComponents.red) * clampedProgress)),
            green: Double(startComponents.green + ((endComponents.green - startComponents.green) * clampedProgress)),
            blue: Double(startComponents.blue + ((endComponents.blue - startComponents.blue) * clampedProgress))
        )
    }
}
