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
    let previousDailySummaries: [HistoricalEnergySummaryValue]

    static func make(
        months: [HistoricalEnergySummaryValue],
        selectedMonth: HistoricalEnergySummaryValue?,
        dailySummaries: [HistoricalEnergySummaryValue],
        previousDailySummaries: [HistoricalEnergySummaryValue] = [],
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
        let lastMeasured = selectedMonth.flatMap { selected in
            SameDayMonthComparison.lastMeasuredDay(
                monthStart: selected.periodStart,
                dailySummaries: dailySummaries,
                extraDates: liveConsumption?.values.filter { $0.kWh > 0 }.map(\.date) ?? [],
                calendar: calendar
            )
        } ?? (isCurrentMonth ? now : nil)
        let throughDay = previous.flatMap { previousMonth in
            selectedMonth.flatMap { selected in
                SameDayMonthComparison.throughDay(
                    currentMonthStart: selected.periodStart,
                    lastMeasuredInCurrent: lastMeasured,
                    previousMonthStart: previousMonth.periodStart,
                    now: now,
                    calendar: calendar
                )
            }
        }
        let comparesSameDays = throughDay != nil
        let comparisonCurrent: HistoryMonthSnapshot?
        let comparisonPrevious: HistoryMonthSnapshot?
        let comparisonMonthName: String?
        if let throughDay, let snapshot, let previousSnapshot,
           let alignedPrevious = HistoryInsights.alignedSnapshot(
            base: previousSnapshot,
            dailySummaries: previousDailySummaries,
            liveConsumption: nil,
            throughDay: throughDay,
            costProfile: costProfile,
            now: now,
            calendar: calendar
           ) {
            comparisonCurrent = HistoryInsights.alignedSnapshot(
                base: snapshot,
                dailySummaries: dailySummaries,
                liveConsumption: liveConsumption,
                throughDay: throughDay,
                costProfile: costProfile,
                now: now,
                calendar: calendar
            ) ?? snapshot
            comparisonPrevious = alignedPrevious
            comparisonMonthName = previous.map {
                SameDayMonthComparison.rangeLabel(throughDay: throughDay, monthStart: $0.periodStart)
            }
        } else if throughDay == nil {
            comparisonCurrent = snapshot
            comparisonPrevious = previousSnapshot
            comparisonMonthName = previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) }
        } else {
            comparisonCurrent = snapshot
            comparisonPrevious = nil
            comparisonMonthName = nil
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
            comparison: comparisonCurrent.flatMap {
                HistoryInsights.comparison(
                    current: $0,
                    previous: comparisonPrevious,
                    previousRangeLabel: comparisonMonthName ?? "",
                    comparesSameDays: comparesSameDays
                )
            },
            split: comparisonCurrent.flatMap {
                HistoryInsights.priceConsumptionSplit(
                    current: $0,
                    previous: comparisonPrevious,
                    previousRangeLabel: comparisonMonthName ?? "",
                    comparesSameDays: comparesSameDays
                )
            },
            dayBars: dayBars,
            weekdayAverages: HistoryInsights.weekdayAverages(from: dayBars, calendar: calendar),
            comparisonMonthName: comparisonMonthName,
            previousDailySummaries: previousDailySummaries
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
