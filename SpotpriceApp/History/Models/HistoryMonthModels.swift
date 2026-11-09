import Foundation

enum HistoryMonthLoadState {
    case loading
    case loaded(HistoryMonthPresentation)
    case empty(String)
}

struct HistoryMonthPresentation {
    let months: [HistoricalEnergySummaryValue]
    let selectedMonth: HistoricalEnergySummaryValue?
    let dailySummaries: [HistoricalEnergySummaryValue]
    let hasPastMonths: Bool
    let isCurrentMonth: Bool
    let snapshot: HistoryMonthSnapshot?
    let previousSnapshot: HistoryMonthSnapshot?
    let comparison: HistoryMonthComparison?
    let split: HistoryPriceConsumptionSplit?
    let dayBars: [MonthDayCost]
    let weekdayAverages: [HistoryWeekdayAverage]
    let comparisonMonthName: String?

    static func make(
        months: [HistoricalEnergySummaryValue],
        selectedMonth: HistoricalEnergySummaryValue?,
        dailySummaries: [HistoricalEnergySummaryValue],
        costProfile: CostProfile,
        liveMonthlyConsumption: ConsumptionData?,
        livePreciseCost: PreciseMonthlyCost?,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> HistoryMonthPresentation {
        let isCurrentMonth = selectedMonth.map {
            $0.periodKey == EnergyHistoryKey.monthKey(for: now, calendar: calendar)
        } ?? false
        let liveConsumption = isCurrentMonth ? liveMonthlyConsumption : nil
        let liveCost = isCurrentMonth ? livePreciseCost : nil
        let snapshot = selectedMonth.map { selected in
            HistoryInsights.snapshot(
                summary: selected,
                costProfile: costProfile,
                liveMonthlyConsumption: liveConsumption,
                livePreciseCost: liveCost,
                now: now,
                calendar: calendar
            )
        }
        let previous = selectedMonth.flatMap { HistoryInsights.previousMonth(of: $0, in: months) }
        let previousSnapshot = previous.map { month in
            HistoryInsights.snapshot(
                summary: month,
                costProfile: costProfile,
                liveMonthlyConsumption: nil,
                livePreciseCost: nil,
                now: now,
                calendar: calendar
            )
        }
        let dayBars: [MonthDayCost]
        if let selectedMonth {
            let monthStart = calendar.dateInterval(of: .month, for: selectedMonth.periodStart)?.start
                ?? selectedMonth.periodStart
            dayBars = MonthDailyCostBuilder.bars(
                from: dailySummaries,
                profile: costProfile,
                monthStart: monthStart,
                lastDay: HistoryInsights.lastDayOfMonth(
                    containing: selectedMonth.periodStart,
                    now: now,
                    calendar: calendar
                ),
                now: now,
                calendar: calendar
            )
        } else {
            dayBars = []
        }

        return HistoryMonthPresentation(
            months: months,
            selectedMonth: selectedMonth,
            dailySummaries: dailySummaries,
            hasPastMonths: months.contains { !HistoryMonthFormatting.isCurrentMonth($0, calendar: calendar) },
            isCurrentMonth: isCurrentMonth,
            snapshot: snapshot,
            previousSnapshot: previousSnapshot,
            comparison: snapshot.flatMap { HistoryInsights.comparison(current: $0, previous: previousSnapshot) },
            split: snapshot.flatMap { HistoryInsights.priceConsumptionSplit(current: $0, previous: previousSnapshot) },
            dayBars: dayBars,
            weekdayAverages: HistoryInsights.weekdayAverages(from: dayBars, calendar: calendar),
            comparisonMonthName: previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) }
        )
    }
}

enum HistoryMonthFormatting {
    static func isCurrentMonth(
        _ summary: HistoricalEnergySummaryValue,
        calendar: Calendar = .energyHistory
    ) -> Bool {
        summary.periodKey == EnergyHistoryKey.monthKey(for: Date(), calendar: calendar)
    }
}
