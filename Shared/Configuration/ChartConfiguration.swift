//
//  ChartConfiguration.swift
//  Spotprice
//

import SwiftUI

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

/// Precomputed chart inputs for the iOS total-price line chart.
struct TotalPriceChartSeries {
    let buckets: [PriceBucket]
    let prices: [Double]
    let yDomain: ClosedRange<Double>
    let lineGradient: LinearGradient

    private let minPrice: Double
    private let maxPrice: Double

    init(day: DayChartData, profile: CostProfile, service: TotalCostService = TotalCostService()) {
        buckets = day.buckets
        prices = day.buckets.map { service.calculatePricePerKWh(spotPriceOre: $0.orePerKWh, profile: profile) }

        let minValue = prices.min() ?? 0
        let maxValue = prices.max() ?? minValue
        minPrice = minValue
        maxPrice = maxValue
        yDomain = Self.yDomain(for: prices)
        lineGradient = Self.lineGradient(prices: prices, min: minValue, max: maxValue)
    }

    func price(for bucket: PriceBucket) -> Double {
        guard let index = buckets.firstIndex(where: { $0.id == bucket.id }) else { return 0 }
        return prices[index]
    }

    func color(for bucket: PriceBucket) -> Color {
        smoothPriceColor(for: price(for: bucket))
    }

    private func smoothPriceColor(for price: Double) -> Color {
        let range = maxPrice - minPrice
        guard range > 0 else { return DS.Color.warning }

        let normalized = Swift.min(Swift.max((price - minPrice) / range, 0), 1)
        switch normalized {
        case ..<0.5:
            return Self.interpolateColor(
                from: Color(red: 0.02, green: 0.56, blue: 0.24),
                to: Color(red: 0.95, green: 0.38, blue: 0.02),
                progress: normalized / 0.5
            )
        default:
            return Self.interpolateColor(
                from: Color(red: 0.95, green: 0.38, blue: 0.02),
                to: Color(red: 0.82, green: 0.04, blue: 0.04),
                progress: (normalized - 0.5) / 0.5
            )
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

    private static func smoothPriceColor(for price: Double, min minPrice: Double, max maxPrice: Double) -> Color {
        let range = maxPrice - minPrice
        guard range > 0 else { return DS.Color.warning }

        let normalized = Swift.min(Swift.max((price - minPrice) / range, 0), 1)
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
