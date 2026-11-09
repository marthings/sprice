import Foundation

enum HistoryMonthLoadState {
    case loading
    case loaded(HistoryMonthData)
    case empty(String)
}

struct HistoryMonthData {
    let months: [HistoricalEnergySummaryValue]
    let selectedMonth: HistoricalEnergySummaryValue?
    let dailySummaries: [HistoricalEnergySummaryValue]
}

enum HistoryMonthFormatting {
    static func isCurrentMonth(
        _ summary: HistoricalEnergySummaryValue,
        calendar: Calendar = .energyHistory
    ) -> Bool {
        summary.periodKey == EnergyHistoryKey.monthKey(for: Date(), calendar: calendar)
    }
}
