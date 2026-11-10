import SwiftUI

struct HistoryMonthLoadedContent: View {
    let presentation: HistoryMonthPresentation
    let hasProvider: Bool
    let priceArea: String
    let costProfile: CostProfile
    let historyQuery: (any EnergyHistoryQuerying)?
    var previewInsights: ConsumptionInsights? = nil

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

                if presentation.hasPastMonths {
                    Text("Äldre månader räknas med de priser och avgifter du har i dag, inte de som gällde då.")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let snapshot = presentation.snapshot {
                    HistoryMonthHeroSection(
                        snapshot: snapshot,
                        comparison: presentation.comparison,
                        previousMonthName: presentation.comparisonMonthName
                            ?? presentation.previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) },
                        hasProvider: hasProvider
                    )

                    if presentation.previousSnapshot != nil {
                        HistoryPriceConsumptionEffect(
                            split: presentation.split,
                            previousMonthName: presentation.comparisonMonthName
                                ?? presentation.previousSnapshot.map { AppFormatters.monthName($0.summary.periodStart) }
                        )
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
