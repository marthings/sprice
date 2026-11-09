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
        var comparisonCurrent = snapshot
        var comparisonPrevious = previousSnapshot
        var comparisonMonthName = previousSnapshot.map { SameDayMonthComparison.swedishMonthName($0.summary.periodStart) }
        if let throughDay, let snapshot, let previousSnapshot {
            comparisonMonthName = previous.map {
                SameDayMonthComparison.rangeLabel(throughDay: throughDay, monthStart: $0.periodStart)
            } ?? comparisonMonthName
            if let alignedPrevious = HistoryInsights.alignedSnapshot(
                base: previousSnapshot,
                dailySummaries: previousDailySummaries,
                liveConsumption: nil,
                throughDay: throughDay,
                costProfile: costProfile,
                now: now,
                calendar: calendar
            ), let alignedCurrent = HistoryInsights.alignedSnapshot(
                base: snapshot,
                dailySummaries: dailySummaries,
                liveConsumption: liveConsumption,
                throughDay: throughDay,
                costProfile: costProfile,
                now: now,
                calendar: calendar
            ), HistoryInsights.alignedCostMatchesDisplayed(aligned: alignedCurrent, displayed: snapshot) {
                // Keep the hero total as the comparison current so 856 kr
                // and "X kr mer än 1–8 oktober" describe the same number.
                comparisonCurrent = snapshot
                comparisonPrevious = alignedPrevious
            } else {
                comparisonPrevious = nil
            }
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
