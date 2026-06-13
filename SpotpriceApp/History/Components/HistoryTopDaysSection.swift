import SwiftUI

struct HistoryTopDaysSection: View {
    let title: String
    let emptyMessage: String
    let days: [HistoricalEnergySummaryValue]
    let value: (HistoricalEnergySummaryValue) -> (String, String)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.headline)

            if days.isEmpty {
                Text(emptyMessage)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                ForEach(days) { day in
                    HistorySummaryRow(summary: day, value: value(day))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}