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
                .font(.system(size: fontSize, weight: .semibold))
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
            case .compact: return DS.Font.bold(16)
            case .regular: return DS.Font.black(20)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            if style == .regular {
                SectionInfoHeader(
                    title: sectionTitle,
                    titleFont: style.titleFont,
                    titleColor: style.titleColor,
                    paragraphs: [
                        "Dagens lägsta, högsta och snittpris per kilowattimme.",
                        profile.isSpotFollowingRetailContract
                            ? "Det är vad du betalar, med skatt, avgifter och moms, precis som i grafen."
                            : "Det är marknadens elpris, utan påslag, elnät, skatt och moms."
                    ]
                )
            } else {
                Text(sectionTitle)
                    .font(style.titleFont)
                    .foregroundStyle(style.titleColor)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.sm) {
                    statCards(stacked: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        statCards(stacked: false)
                    }
                    VStack(spacing: DS.Spacing.sm) {
                        statCards(stacked: true)
                    }
                }
            }

            if let comparisonText {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: comparisonIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(comparisonColor)
                    Text(comparisonText)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statCards(stacked: Bool) -> some View {
        statCard(title: "Lägsta", value: minValue, color: DS.Color.successText, icon: "arrow.down.circle.fill", stacked: stacked)
        statCard(title: "Högsta", value: maxValue, color: DS.Color.dangerText, icon: "arrow.up.circle.fill", stacked: stacked)
        statCard(title: "Snitt", value: averageValue, color: DS.Color.infoText, icon: "chart.line.uptrend.xyaxis", stacked: stacked)
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
        guard let contractPrice = profile.contractPriceOrePerKWh else { return DS.Color.infoText }
        return PriceBucketAnalytics.averageSpotPrice(dayData.buckets) < contractPrice ? DS.Color.successText : DS.Color.dangerText
    }

    private func statCard(title: String, value: Double, color: Color, icon: String, stacked: Bool) -> some View {
        Group {
            if stacked {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(DS.Font.footnote)
                        .foregroundStyle(style == .compact ? .primary : DS.Color.secondary)
                    Spacer(minLength: DS.Spacing.sm)
                    priceValue(value, color: color)
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // The arrow and the word say what the color says, so the card
                    // reads the same without color.
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(DS.Font.footnote)
                            .foregroundStyle(style == .compact ? .primary : DS.Color.secondary)
                            .lineLimit(1)
                    }

                    priceValue(value, color: color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, style == .compact ? DS.Spacing.sm : DS.Spacing.md)
        .padding(.horizontal, style == .compact ? DS.Spacing.sm : DS.Spacing.md)
        .spriceCard(tone: .price)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(2)))) kronor per kilowattimme")
    }

    private func priceValue(_ value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(style.valueFont)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text("kr/kWh")
                .font(DS.Font.unit)
                .foregroundStyle(DS.Color.secondary)
        }
    }

}
