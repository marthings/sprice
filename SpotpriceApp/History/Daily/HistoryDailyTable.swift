import SwiftUI

struct HistoryDailyTable: View {
    let days: [HistoricalEnergySummaryValue]

    var body: some View {
        ForEach(days) { day in
            HistorySummaryRow(
                summary: day,
                value: HistoryMonthFormatting.primaryDayValue(for: day)
            )
        }
    }
}