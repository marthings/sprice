import SwiftUI

struct HistoryMonthLoadedContent: View {
    let data: HistoryMonthData
    let costProfile: CostProfile
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?
    let hasProvider: Bool

    @Binding var selectedMonthKey: String?
    @Binding var openedDay: HistoryDayRoute?

    var body: some View {
        if data.months.isEmpty {
            AppStatusCard(
                icon: "clock.badge",
                title: "Ingen historik att visa",
                message: HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider),
                color: DS.Color.secondary
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HistoryMonthChrome(
                    months: data.months,
                    selectedMonth: data.selectedMonth,
                    comparisonMonthName: previousSnapshot.map {
                        AppFormatters.monthName($0.summary.periodStart)
                    },
                    selectedMonthKey: $selectedMonthKey
                )

                if let snapshot {
                    HistoryMonthHeroSection(
                        snapshot: snapshot,
                        comparison: comparison,
                        hasProvider: hasProvider
                    )

                    if previousSnapshot != nil {
                        HistoryPriceConsumptionEffect(
                            split: split,
                            previousMonthName: previousSnapshot.map {
                                AppFormatters.monthName($0.summary.periodStart)
                            }
                        )
                    }

                    HistoryPaidVersusSpot(snapshot: snapshot)

                    HistoryMonthDaysChart(
                        days: dayBars,
                        isCurrentMonth: snapshot.isCurrentMonth,
                        hasProvider: hasProvider,
                        openedDay: $openedDay
                    )

                    HistoryWeekdayPattern(averages: weekdayAverages)
                }
            }
        }
    }

    private var snapshot: HistoryMonthSnapshot? {
        guard let selected = data.selectedMonth else { return nil }
        return HistoryInsights.snapshot(
            summary: selected,
            costProfile: costProfile,
            liveMonthlyConsumption: liveMonthlyConsumption,
            livePreciseCost: livePreciseCost
        )
    }

    private var previousSnapshot: HistoryMonthSnapshot? {
        guard let selected = data.selectedMonth,
              let previous = HistoryInsights.previousMonth(of: selected, in: data.months) else {
            return nil
        }
        return HistoryInsights.snapshot(
            summary: previous,
            costProfile: costProfile,
            liveMonthlyConsumption: nil,
            livePreciseCost: nil
        )
    }

    private var comparison: HistoryMonthComparison? {
        guard let snapshot else { return nil }
        return HistoryInsights.comparison(current: snapshot, previous: previousSnapshot)
    }

    private var split: HistoryPriceConsumptionSplit? {
        guard let snapshot else { return nil }
        return HistoryInsights.priceConsumptionSplit(current: snapshot, previous: previousSnapshot)
    }

    private var dayBars: [MonthDayCost] {
        guard let selected = data.selectedMonth else { return [] }
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: selected.periodStart)?.start ?? selected.periodStart
        return MonthDailyCostBuilder.bars(
            from: data.dailySummaries,
            profile: costProfile,
            monthStart: monthStart,
            lastDay: HistoryInsights.lastDayOfMonth(containing: selected.periodStart, now: now, calendar: calendar),
            now: now,
            calendar: calendar
        )
    }

    private var weekdayAverages: [HistoryWeekdayAverage] {
        HistoryInsights.weekdayAverages(from: dayBars)
    }
}
