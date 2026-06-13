import SwiftUI

struct HistoryDayCalloutView: View {
    let day: HistoricalEnergySummaryValue
    var showCoverageBadge = true

    @Environment(\.colorScheme) private var colorScheme

    private var calloutBackground: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Color.white
    }

    private var calloutStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.72)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Text(AppFormatters.historyDayLabel(day.periodStart))
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                if showCoverageBadge {
                    Text(day.dataCoverage.calloutTitle)
                        .font(DS.Font.micro)
                        .foregroundStyle(day.dataCoverage.displayColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(day.dataCoverage.displayColor.opacity(0.15), in: Capsule())
                }
            }

            Divider()
                .padding(.vertical, DS.Spacing.xxs)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let cost = day.totalCostSEK {
                    metricRow(
                        icon: "wallet.bifold.fill",
                        label: "Kostnad",
                        value: AppFormatters.wholeNumber(cost),
                        unit: "kr",
                        highlight: true
                    )
                }

                if let consumption = day.totalConsumptionKWh {
                    metricRow(
                        icon: "bolt.fill",
                        label: "Förbrukning",
                        value: consumption.formatted(.number.precision(.fractionLength(1))),
                        unit: "kWh",
                        highlight: day.totalCostSEK == nil
                    )
                }

                if let avgPrice = day.averageSpotPriceOrePerKWh {
                    metricRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Snitt spotpris",
                        value: AppFormatters.oreValue(avgPrice),
                        unit: "öre/kWh",
                        highlight: false
                    )
                }

                if let avgTotalPrice = day.averageTotalCostSEKPerKWh {
                    metricRow(
                        icon: "chart.bar.fill",
                        label: "Snitt totalpris",
                        value: avgTotalPrice.formatted(.number.precision(.fractionLength(2))),
                        unit: "kr/kWh",
                        highlight: false
                    )
                }
            }
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(calloutBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(calloutStroke, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: DS.Spacing.sm, x: 0, y: DS.Spacing.xs)
    }

    private func metricRow(
        icon: String,
        label: String,
        value: String,
        unit: String,
        highlight: Bool
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(highlight ? primaryTextColor : secondaryTextColor)
                .frame(width: 12)

            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(secondaryTextColor)

            Spacer()

            Text(value)
                .font(DS.Font.medium(11).monospacedDigit())
                .foregroundStyle(highlight ? primaryTextColor : secondaryTextColor)

            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(secondaryTextColor)
        }
    }
}