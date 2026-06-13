import SwiftUI

struct HistoryMonthLoadedContent: View {
    let data: HistoryMonthData
    let costProfile: CostProfile
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?

    @Binding var selectedMonthKey: String?
    @Binding var viewMode: HistoryMonthViewMode
    @Binding var selectedDay: HistoricalEnergySummaryValue?

    var body: some View {
        if data.months.isEmpty {
            AppStatusCard(
                icon: "clock.badge",
                title: "Ingen sparad historik än",
                message: "Historik fylls på automatiskt efter lyckade prisuppdateringar. Förbrukning och kostnad visas när sådan data finns sparad.",
                color: DS.Color.secondary
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HistoryMonthPicker(months: data.months, selectedMonthKey: $selectedMonthKey)

                if let selectedMonth = data.selectedMonth {
                    let isCurrent = HistoryMonthFormatting.isCurrentMonth(selectedMonth)

                    HistoryMonthSummaryCards(
                        summary: selectedMonth,
                        costProfile: costProfile,
                        isCurrentMonth: isCurrent,
                        liveMonthlyConsumption: liveMonthlyConsumption,
                        livePreciseCost: livePreciseCost
                    )

                    HistoryTopDaysSection(
                        title: "Dyraste dagar",
                        emptyMessage: "Kostnadsdagar visas när historiken innehåller beräknad kostnad.",
                        days: data.topCostDays,
                        value: { summary in
                            HistoryMonthFormatting.topCostValue(
                                for: summary,
                                isCurrentMonth: isCurrent,
                                costProfile: costProfile
                            )
                        }
                    )

                    HistoryTopDaysSection(
                        title: "Högst förbrukning",
                        emptyMessage: "Förbrukningsdagar visas när en datakälla har levererat mätvärden.",
                        days: data.topConsumptionDays,
                        value: HistoryMonthFormatting.topConsumptionValue(for:)
                    )
                }

                HistoryDailyList(
                    days: data.dailySummaries,
                    viewMode: $viewMode,
                    selectedDay: $selectedDay
                )
            }
        }
    }
}