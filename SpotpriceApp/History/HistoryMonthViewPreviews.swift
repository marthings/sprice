#if DEBUG
import SwiftUI

#Preview("Med historik") {
    previewContainer(HistoryMonthView(
        priceArea: "SE3",
        costProfile: .swedishDefaultEstimate()
    ))
}

#Preview("Tom historik") {
    previewContainer(HistoryMonthView(
        priceArea: "SE3",
        costProfile: .swedishDefaultEstimate(),
        previewState: .empty(HistoryInsights.emptyHistoryMessage(hasProvider: false))
    ))
}

#Preview("Mock data - Mätt") {
    previewContainer(HistoryMonthPreviewData.measuredHistoryView)
}

#Preview("Mock data - Blandat") {
    previewContainer(HistoryMonthPreviewData.mixedHistoryView)
}

private func previewContainer<Content: View>(_ content: Content) -> some View {
    NavigationStack {
        content
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}

private enum HistoryMonthPreviewData {
    static var measuredHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let previousStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        let dailySummaries = measuredDailySummaries(calendar: calendar, monthStart: previousStart)
        let monthlySummary = makeMonthlySummary(
            start: previousStart,
            dailySummaries: dailySummaries,
            measuredCount: 720,
            confidence: .measured
        )
        let previousSummary = makeMonthlySummary(
            start: calendar.date(byAdding: .month, value: -1, to: previousStart)!,
            dailySummaries: dailySummaries,
            measuredCount: 720,
            confidence: .measured
        )

        return historyView(months: [monthlySummary, previousSummary], selected: monthlySummary, dailySummaries: dailySummaries)
    }

    static var mixedHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let dailySummaries = mixedDailySummaries(calendar: calendar, monthStart: monthStart)
        let monthlySummary = makeMonthlySummary(
            start: monthStart,
            dailySummaries: dailySummaries,
            measuredCount: 360,
            confidence: .partial
        )

        return historyView(months: [monthlySummary], selected: monthlySummary, dailySummaries: dailySummaries)
    }

    private static func historyView(
        months: [HistoricalEnergySummaryValue],
        selected: HistoricalEnergySummaryValue,
        dailySummaries: [HistoricalEnergySummaryValue]
    ) -> some View {
        HistoryMonthView(
            priceArea: "SE3",
            costProfile: .swedishDefaultEstimate(),
            previewState: .loaded(HistoryMonthData(
                months: months,
                selectedMonth: selected,
                dailySummaries: dailySummaries
            ))
        )
    }

    private static func makeMonthlySummary(
        start: Date,
        dailySummaries: [HistoricalEnergySummaryValue],
        measuredCount: Int,
        confidence: HistoricalEnergyConfidence
    ) -> HistoricalEnergySummaryValue {
        HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: start),
            periodStart: start,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 720,
            measuredIntervalCount: measuredCount,
            totalConsumptionKWh: dailySummaries.compactMap(\.totalConsumptionKWh).reduce(0, +),
            totalCostSEK: dailySummaries.compactMap(\.totalCostSEK).reduce(0, +),
            averageSpotPriceOrePerKWh: 75.5,
            minSpotPriceOrePerKWh: 20.0,
            maxSpotPriceOrePerKWh: 180.0,
            confidence: confidence
        )
    }

    private static func measuredDailySummaries(
        calendar: Calendar,
        monthStart: Date
    ) -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
            return makeDailySummary(
                date: date,
                measuredCount: 24,
                consumption: Double.random(in: 30...60),
                cost: Double.random(in: 150...350),
                confidence: .measured
            )
        }
    }

    private static func mixedDailySummaries(
        calendar: Calendar,
        monthStart: Date
    ) -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!

            switch dayOffset % 4 {
            case 0:
                return makeDailySummary(
                    date: date,
                    measuredCount: 24,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .measured
                )
            case 1:
                return makeDailySummary(
                    date: date,
                    measuredCount: 12,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .partial
                )
            case 2:
                return makeDailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: Double.random(in: 150...350),
                    confidence: .estimated
                )
            default:
                return makeDailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: nil,
                    confidence: .priceOnly
                )
            }
        }
    }

    private static func makeDailySummary(
        date: Date,
        measuredCount: Int,
        consumption: Double?,
        cost: Double?,
        confidence: HistoricalEnergyConfidence
    ) -> HistoricalEnergySummaryValue {
        HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.dayKey(for: date),
            periodStart: date,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 24,
            measuredIntervalCount: measuredCount,
            totalConsumptionKWh: consumption,
            totalCostSEK: cost,
            averageSpotPriceOrePerKWh: Double.random(in: 40...120),
            minSpotPriceOrePerKWh: Double.random(in: 20...60),
            maxSpotPriceOrePerKWh: Double.random(in: 80...180),
            confidence: confidence
        )
    }
}
#endif
