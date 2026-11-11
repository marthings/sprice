import SwiftUI

struct HistoryMonthLoadedContent: View {
    let presentation: HistoryMonthPresentation
    let hasProvider: Bool
    let priceArea: String
    let costProfile: CostProfile
    let historyQuery: (any EnergyHistoryQuerying)?
    var previewInsights: ConsumptionInsights? = nil
    var temperatureInsights: [TemperatureInsight] = []
    var dailyTemperatures: [Date: Double] = [:]

    @Binding var selectedMonthKey: String?
    @Binding var openedDay: HistoryDayRoute?
    @Binding var openedInsights: ConsumptionInsightsRoute?

    var body: some View {
        if presentation.months.isEmpty {
            AppStatusCard(
                icon: "clock.badge",
                title: "Ingen historik att visa",
                message: HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider),
                color: DS.Color.secondary
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HistoryMonthChrome(
                    months: presentation.months,
                    selectedMonth: presentation.selectedMonth,
                    comparisonMonthName: presentation.comparisonMonthName,
                    selectedMonthKey: $selectedMonthKey
                )

                if let snapshot = presentation.snapshot {
                    HistoryMonthHeroSection(
                        snapshot: snapshot,
                        comparison: presentation.comparison,
                        previousMonthName: presentation.comparisonMonthName
                            ?? presentation.previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) },
                        hasProvider: hasProvider,
                        hasPastMonths: presentation.hasPastMonths,
                        temperatureInsights: temperatureInsights,
                        priceArea: priceArea,
                        monthKey: presentation.selectedMonth?.periodKey
                    )

                    if presentation.previousSnapshot != nil {
                        HistoryPriceConsumptionEffect(
                            split: presentation.split,
                            priceArea: priceArea,
                            currentMonthKey: presentation.selectedMonth?.periodKey,
                            previousMonthKey: presentation.previousSnapshot?.summary.periodKey,
                            throughDay: presentation.comparisonThroughDay,
                            previousMonthName: presentation.comparisonMonthName
                                ?? presentation.previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) }
                        )
                    }

                    HistoryPaidVersusSpot(
                        snapshot: snapshot,
                        priceArea: priceArea,
                        costProfile: costProfile,
                        monthKey: presentation.selectedMonth?.periodKey
                    )

                    ConsumptionInsightsMonthSection(
                        presentation: presentation,
                        priceArea: priceArea,
                        costProfile: costProfile,
                        historyQuery: historyQuery,
                        openedInsights: $openedInsights,
                        previewInsights: previewInsights
                    )

                    HistoryMonthDaysChart(
                        days: presentation.dayBars,
                        isCurrentMonth: snapshot.isCurrentMonth,
                        hasProvider: hasProvider,
                        temperatures: dailyTemperatures,
                        openedDay: $openedDay
                    )

                    HistoryWeekdayPattern(averages: presentation.weekdayAverages)
                }
            }
        }
    }
}
