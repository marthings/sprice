//
//  PriceChangeIndicator.swift
//  Spotprice
//

import SwiftUI

struct PriceChangeIndicator: View {
    let current: Double?
    let next: Double?
    var fontSize: CGFloat = 10

    var body: some View {
        if let current, let next {
            let change = next - current
            let isIncrease = change > 0
            let isDecrease = change < 0

            // Use semantic icons and colors for accessibility
            let icon = isIncrease ? "arrow.up.right" : isDecrease ? "arrow.down.right" : "arrow.right"
            let color: Color = isIncrease ? DS.Color.danger : isDecrease ? DS.Color.success : DS.Color.secondary

            Image(systemName: icon)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(color)
                .accessibilityLabel(isIncrease ? "Ökar" : isDecrease ? "Minskar" : "Stabilt")
        }
    }
}

struct SharedPriceRangeSection: View {
    enum Style {
        case compact
        case regular

        var titleFont: Font {
            switch self {
            case .compact: return DS.Font.semibold(12)
            case .regular: return DS.Font.headline
            }
        }

        var titleColor: Color {
            switch self {
            case .compact: return DS.Color.secondary
            case .regular: return .primary
            }
        }

        var valueFont: Font {
            switch self {
            case .compact: return DS.Font.bold(16).monospacedDigit()
            case .regular: return DS.Font.bold(17).monospacedDigit()
            }
        }

        var showsIcons: Bool {
            self == .compact
        }
    }

    let dayData: DayChartData
    let profile: CostProfile
    var style: Style = .regular

    private let totalCostService = TotalCostService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(sectionTitle)
                .font(style.titleFont)
                .foregroundStyle(style.titleColor)

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                statCard(title: "Lägsta", value: minValue, color: DS.Color.success, icon: "arrow.down.circle.fill")
                statCard(title: "Högsta", value: maxValue, color: DS.Color.danger, icon: "arrow.up.circle.fill")
                statCard(title: "Snitt", value: averageValue, color: DS.Color.info, icon: "chart.line.uptrend.xyaxis")
            }

            if let comparisonText {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: comparisonIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(comparisonColor)
                    Text(comparisonText)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm)
        ]
    }

    private var sectionTitle: String {
        profile.isSpotFollowingRetailContract ? "Prisspann idag" : "Marknadens prisspann idag"
    }

    private var minValue: Double {
        profile.isSpotFollowingRetailContract
            ? totalCostService.calculatePricePerKWh(spotPriceOre: dayData.minOre, profile: profile)
            : dayData.minOre / 100
    }

    private var maxValue: Double {
        profile.isSpotFollowingRetailContract
            ? totalCostService.calculatePricePerKWh(spotPriceOre: dayData.maxOre, profile: profile)
            : dayData.maxOre / 100
    }

    private var averageValue: Double {
        let averageSpotPrice = PriceBucketAnalytics.averageSpotPrice(dayData.buckets)
        return profile.isSpotFollowingRetailContract
            ? totalCostService.calculatePricePerKWh(spotPriceOre: averageSpotPrice, profile: profile)
            : averageSpotPrice / 100
    }

    private var comparisonText: String? {
        guard !profile.isSpotFollowingRetailContract,
              let contractPrice = profile.contractPriceOrePerKWh else {
            return nil
        }

        return PriceBucketAnalytics.averageSpotPrice(dayData.buckets) < contractPrice
            ? "Marknaden är i snitt billigare än ditt avtal idag."
            : "Ditt avtal är billigare än marknaden i snitt idag."
    }

    private var comparisonIcon: String {
        guard let contractPrice = profile.contractPriceOrePerKWh else { return "info.circle.fill" }
        return PriceBucketAnalytics.averageSpotPrice(dayData.buckets) < contractPrice ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    private var comparisonColor: Color {
        guard let contractPrice = profile.contractPriceOrePerKWh else { return DS.Color.info }
        return PriceBucketAnalytics.averageSpotPrice(dayData.buckets) < contractPrice ? DS.Color.success : DS.Color.danger
    }

    private func statCard(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            if style.showsIcons {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(style == .compact ? .primary : DS.Color.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(style.valueFont)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text("kr")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, style == .compact ? DS.Spacing.sm : DS.Spacing.md)
        .padding(.horizontal, style == .compact ? DS.Spacing.xs : DS.Spacing.sm)
        .spriceCard(tone: .price)
    }

}
