import SwiftUI

struct HistoryMonthPicker: View {
    let months: [HistoricalEnergySummaryValue]
    @Binding var selectedMonthKey: String?

    var body: some View {
        Picker("Månad", selection: Binding(
            get: { selectedMonthKey ?? months.first?.periodKey ?? "" },
            set: { selectedMonthKey = $0 }
        )) {
            ForEach(months) { month in
                Text(AppFormatters.historyMonthLabel(month.periodStart))
                    .tag(month.periodKey)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}