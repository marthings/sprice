import SwiftUI

struct HistorySummaryRow: View {
    let summary: HistoricalEnergySummaryValue
    let value: (String, String)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(AppFormatters.historyDayLabel(summary.periodStart))
                    .font(DS.Font.callout)
            }

            Spacer(minLength: DS.Spacing.sm)

            if let value {
                HStack(alignment: .center, spacing: DS.Spacing.xs) {
                    metricValue(value)

                    if let secondaryValue = secondaryValue(for: summary, primaryUnit: value.1) {
                        metricValue(secondaryValue)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            } else {
                Text("-")
                    .font(DS.Font.semibold(16).monospacedDigit())
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func metricValue(_ value: (String, String)) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
            Text(value.0)
                .font(DS.Font.semibold(16).monospacedDigit())
            Text(value.1)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private func secondaryValue(
        for summary: HistoricalEnergySummaryValue,
        primaryUnit: String
    ) -> (String, String)? {
        if primaryUnit != "kWh", let consumption = summary.totalConsumptionKWh {
            return (AppFormatters.kWhValue(consumption), "kWh")
        }
        if primaryUnit != "kr", let cost = summary.totalCostSEK {
            return (AppFormatters.wholeNumber(cost), "kr")
        }
        return nil
    }
}