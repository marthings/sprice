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

    private static let totalCostService = TotalCostService()

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
        DS.Color.forCategory(priceCategory)
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
            HStack(spacing: DS.Spacing.sm) {
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(primaryTextColor)

                spotPriceLabel

                PriceLevelBadge(category: priceCategory, style: .compact)
            }

            if profile.isSpotFollowingRetailContract {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                HStack(spacing: DS.Spacing.xs) {
                    Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("kr/kWh totalt")
                        .font(DS.Font.micro)
                        .foregroundStyle(secondaryTextColor)
                }

                breakdownRows
            } else if let contractPrice = profile.contractPriceOrePerKWh {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                let difference = bucket.orePerKWh - contractPrice
                let percentDiff = abs((difference / contractPrice) * 100)
                let isGoodDeal = difference > 0
                let displayColor = isGoodDeal ? DS.Color.success : DS.Color.danger
                let iconName = isGoodDeal ? "checkmark.circle.fill" : "xmark.circle.fill"
                let labelText = isGoodDeal ? "Sparar:" : "Förlorar:"

                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(displayColor)
                        Text(labelText)
                            .font(DS.Font.micro)
                            .foregroundStyle(secondaryTextColor)
                        Text("\(percentDiff, specifier: "%.0f")%")
                            .font(DS.Font.medium(11).monospacedDigit())
                            .foregroundStyle(displayColor)
                    }
                    Spacer()
                    HStack(spacing: DS.Spacing.xs) {
                        Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.bold(14).monospacedDigit())
                            .foregroundStyle(.blue)
                        Text("kr/kWh")
                            .font(DS.Font.micro)
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

    @ViewBuilder
    private var spotPriceLabel: some View {
        HStack(spacing: DS.Spacing.xs) {
            switch style {
            case .material:
                Text(bucket.orePerKWh / 100, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.medium(11).monospacedDigit())
                    .foregroundStyle(priceColor)
                Text("kr/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(secondaryTextColor)
            case .opaque:
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(DS.Font.medium(11).monospacedDigit())
                    .foregroundStyle(priceColor)
                Text("öre/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(secondaryTextColor)
            }
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

private struct ChartCalloutBreakdownRow: View {
    let label: String
    let value: Double
    var isMainComponent: Bool = false
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(isMainComponent ? primaryTextColor : secondaryTextColor)
            Spacer()
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.medium(10).monospacedDigit())
                .foregroundStyle(isMainComponent ? primaryTextColor : secondaryTextColor)
            Text("kr")
                .font(DS.Font.micro)
                .foregroundStyle(secondaryTextColor)
        }
    }
}