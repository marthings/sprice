//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

enum ChartCalloutStyle {
    /// Frosted material — menu bar and macOS charts.
    case material
    /// Opaque light/dark surface — iOS charts over colored backgrounds.
    case opaque
}

struct ChartCalloutView: View {
    let bucket: PriceBucket
    let dayData: DayChartData
    let profile: CostProfile
    var style: ChartCalloutStyle

    @Environment(\.colorScheme) private var colorScheme

    private static let totalCostService = TotalCostService.shared

    init(
        bucket: PriceBucket,
        dayData: DayChartData,
        profile: CostProfile,
        style: ChartCalloutStyle = .material
    ) {
        self.bucket = bucket
        self.dayData = dayData
        self.profile = profile
        self.style = style
    }

    private var priceCategory: PriceCategory {
        if !profile.isSpotFollowingRetailContract, let contractPrice = profile.contractPriceOrePerKWh {
            let difference = bucket.orePerKWh - contractPrice
            let percentDiff = abs(difference / contractPrice)

            if difference > 0 {
                return percentDiff >= 0.20 ? .low : .medium
            } else {
                return percentDiff >= 0.20 ? .high : .medium
            }
        } else {
            return DS.Color.categoryForPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
        }
    }

    private var priceColor: Color {
        DS.Color.textForCategory(priceCategory)
    }

    private var totalCostPerKWh: Double {
        Self.totalCostService.calculatePricePerKWh(
            spotPriceOre: bucket.orePerKWh,
            profile: profile
        )
    }

    private var costBreakdown: EnhancedCost {
        Self.totalCostService.calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: bucket.orePerKWh,
            profile: profile,
            hoursInPeriod: 1.0
        )
    }

    private var primaryTextColor: Color {
        switch style {
        case .material:
            return .primary
        case .opaque:
            return colorScheme == .dark ? .white : .black
        }
    }

    private var secondaryTextColor: Color {
        switch style {
        case .material:
            return DS.Color.secondary
        case .opaque:
            return primaryTextColor.opacity(0.72)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.sm) {
                    calloutTime
                    spotPriceLabel
                    PriceLevelBadge(category: priceCategory, style: .compact)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.sm) {
                        calloutTime
                        PriceLevelBadge(category: priceCategory, style: .compact)
                    }
                    spotPriceLabel
                }
            }

            if profile.isSpotFollowingRetailContract {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                HStack(spacing: DS.Spacing.xs) {
                    Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(DS.Color.infoText)
                    Text("kr/kWh totalt")
                        .font(DS.Font.footnote)
                        .foregroundStyle(secondaryTextColor)
                }

                breakdownRows
            } else if let contractPrice = profile.contractPriceOrePerKWh {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                let difference = bucket.orePerKWh - contractPrice
                let percentDiff = abs((difference / contractPrice) * 100)
                let isGoodDeal = difference > 0
                let displayColor = isGoodDeal ? DS.Color.successText : DS.Color.dangerText
                let iconName = isGoodDeal ? "checkmark.circle.fill" : "xmark.circle.fill"
                let labelText = isGoodDeal ? "Sparar:" : "Förlorar:"

                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: iconName)
                            .font(.system(size: 13))
                            .foregroundStyle(displayColor)
                        Text(labelText)
                            .font(DS.Font.footnote)
                            .foregroundStyle(secondaryTextColor)
                        Text("\(percentDiff, specifier: "%.0f")%")
                            .font(DS.Font.medium(11).monospacedDigit())
                            .foregroundStyle(displayColor)
                    }
                    Spacer()
                    HStack(spacing: DS.Spacing.xs) {
                        Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.bold(14).monospacedDigit())
                            .foregroundStyle(DS.Color.infoText)
                        Text("kr/kWh")
                            .font(DS.Font.unit)
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                breakdownRows
            }
        }
        .padding(DS.Spacing.md)
        .background { calloutBackground }
        .shadow(
            color: .black.opacity(style == .opaque && colorScheme == .dark ? 0.35 : 0.15),
            radius: DS.Spacing.sm,
            x: 0,
            y: DS.Spacing.xs
        )
    }

    private var calloutTime: some View {
        Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
            .font(DS.Font.semibold(13))
            .foregroundStyle(primaryTextColor)
    }

    @ViewBuilder
    private var spotPriceLabel: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(bucket.orePerKWh / 100, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.medium(13).monospacedDigit())
                .foregroundStyle(priceColor)
            Text("kr/kWh spotpris")
                .font(DS.Font.footnote)
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var breakdownRows: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            ForEach(CostBreakdownPresenter.topComponents(for: costBreakdown, profile: profile)) { component in
                ChartCalloutBreakdownRow(
                    label: component.label,
                    value: component.value,
                    isMainComponent: component.isMain,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
            }
        }
        .padding(.top, DS.Spacing.xxs)
    }

    @ViewBuilder
    private var calloutBackground: some View {
        switch style {
        case .material:
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        case .opaque:
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(colorScheme == .dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10),
                            lineWidth: 0.5
                        )
                }
        }
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

/// Compact pill used as a chart annotation on bar charts.
/// Opaque fill — `.regularMaterial` renders black in Swift Chart annotations.
struct ChartValueCallout: View {
    var title: String? = nil
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(DS.Font.footnote)
                    .foregroundStyle(secondaryText)
            }
            Text(value)
                .font(DS.Font.semibold(12).monospacedDigit())
                .foregroundStyle(primaryText)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 4, y: 2)
        .fixedSize()
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryText: Color {
        primaryText.opacity(0.72)
    }
}

private struct ChartCalloutBreakdownRow: View {
    let label: String
    let value: Double
    var isMainComponent: Bool = false
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.footnote)
                .foregroundStyle(isMainComponent ? primaryTextColor : secondaryTextColor)
            Spacer()
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.medium(10).monospacedDigit())
                .foregroundStyle(isMainComponent ? primaryTextColor : secondaryTextColor)
            Text("kr")
                .font(DS.Font.unit)
                .foregroundStyle(secondaryTextColor)
        }
    }
}