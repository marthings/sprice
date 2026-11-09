import SwiftUI

struct HistoryMonthLoadedContent: View {
    let presentation: HistoryMonthPresentation
    let hasProvider: Bool

    @Binding var selectedMonthKey: String?
    @Binding var openedDay: HistoryDayRoute?

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
                    Text("Äldre månader räknas med dina nuvarande tariffer, inte med de som gällde då.")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let snapshot = presentation.snapshot {
                    HistoryMonthHeroSection(
                        snapshot: snapshot,
                        comparison: presentation.comparison,
                        hasProvider: hasProvider
                    )

                    if presentation.previousSnapshot != nil {
                        HistoryPriceConsumptionEffect(
                            split: presentation.split,
                            previousMonthName: presentation.comparisonMonthName
                        )
                    }

                    HistoryPaidVersusSpot(snapshot: snapshot)

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
