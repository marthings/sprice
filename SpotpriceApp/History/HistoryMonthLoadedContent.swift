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
                        hasPastMonths: presentation.hasPastMonths
                    )

                    if presentation.previousSnapshot != nil {
                        HistoryPriceConsumptionEffect(
                            split: presentation.split,
                            previousMonthName: presentation.comparisonMonthName
                                ?? presentation.previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) }
                        )
                    }

                    if !temperatureInsights.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            SectionInfoHeader(
                                title: "Temperatur",
                                paragraphs: [
                                    "Jämförelsen tar hänsyn till om det varit kallare eller varmare. Bara uppvärmningen justeras, inte det som huset drar hela tiden.",
                                    "Beräkningen bygger på det senaste mätvärdet och jämför samma antal dagar i båda perioderna.",
                                    "Om det finns för lite underlag, eller om förbrukningen inte följer vädret tydligt, visas ingen justering.",
                                    "Temperaturen kommer från Open-Meteo för den ort du valt under Inställningar."
                                ]
                            )
                            ForEach(temperatureInsights) { insight in
                                InsightRow(
                                    icon: "thermometer.medium",
                                    title: insight.title,
                                    detail: insight.isUncertain ? "Osäker jämförelse" : nil
                                )
                            }
                        }
                    }

                    HistoryPaidVersusSpot(snapshot: snapshot)

                    HistoryFixedPriceComparisonRow(
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

private struct HistoryFixedPriceComparisonRow: View {
    let priceArea: String
    let costProfile: CostProfile
    let monthKey: String?

    @State private var comparison: CostUsageInsights.FixedComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let comparison {
                InsightRow(icon: "arrow.left.arrow.right", title: comparison.title)
            } else {
                // Keep a layout footprint so `.task` is not cancelled on a zero-size view.
                Color.clear.frame(maxWidth: .infinity).frame(height: 1)
            }
        }
        .onAppear { Task { await load() } }
        .task(id: "\(monthKey ?? "")-\(priceArea)-\(ConsumptionSettings.shared.compareFixedPriceOrePerKWh)") {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let monthKey else {
            comparison = nil
            return
        }
        let intervals: [HistoricalEnergyIntervalValue]
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            intervals = ConsumptionInsightsSampleData.previewIntervals()
        } else {
            intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(
                monthKey: monthKey,
                priceArea: priceArea
            )) ?? []
        }
#else
        intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(
            monthKey: monthKey,
            priceArea: priceArea
        )) ?? []
#endif
        let fixedOre = ConsumptionSettings.shared.compareFixedPriceOrePerKWh
        comparison = CostUsageInsights.fixedComparison(
            intervals: intervals,
            profile: costProfile,
            fixedOrePerKWh: fixedOre > 0 ? fixedOre : CostUsageInsights.defaultFixedPriceOrePerKWh
        )
    }
}
