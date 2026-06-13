import SwiftUI

struct HistoryDailyList: View {
    let days: [HistoricalEnergySummaryValue]
    @Binding var viewMode: HistoryMonthViewMode
    @Binding var selectedDay: HistoricalEnergySummaryValue?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Alla sparade dagar")
                    .font(DS.Font.headline)

                Spacer()

                Picker("Visning", selection: $viewMode) {
                    Label("Graf", systemImage: "chart.bar.fill")
                        .tag(HistoryMonthViewMode.chart)
                    Label("Tabell", systemImage: "list.bullet")
                        .tag(HistoryMonthViewMode.table)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if days.isEmpty {
                Text("Inga dagar sparade för vald månad.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                switch viewMode {
                case .chart:
                    HistoryDailyChart(days: days, selectedDay: $selectedDay)
                case .table:
                    HistoryDailyTable(days: days)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}