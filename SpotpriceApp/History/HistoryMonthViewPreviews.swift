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
        previewState: .loaded(HistoryMonthData(
            months: [],
            selectedMonth: nil,
            dailySummaries: [],
            topCostDays: [],
            topConsumptionDays: []
        ))
    ))
}

#Preview("Mock data - Mätt") {
    previewContainer(HistoryMonthPreviewData.measuredHistoryView)
}

#Preview("Mock data - Blandat") {
    previewContainer(HistoryMonthPreviewData.mixedHistoryView)
}

private func previewContainer<Content: View>(_ content: Content) -> some View {
    content
        .padding()
        .background(Color(.systemGroupedBackground))
}

private enum HistoryMonthPreviewData {
    static var measuredHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let dailySummaries = measuredDailySummaries(calendar: calendar, monthStart: monthStart)
        let monthlySummary = HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: now),
            periodStart: monthStart,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 720,
            measuredIntervalCount: 720,
            totalConsumptionKWh: dailySummaries.compactMap(\.totalConsumptionKWh).reduce(0, +),
            totalCostSEK: dailySummaries.compactMap(\.totalCostSEK).reduce(0, +),
            averageSpotPriceOrePerKWh: 75.5,
            minSpotPriceOrePerKWh: 20.0,
            maxSpotPriceOrePerKWh: 180.0,
            confidence: .measured
        )

        return historyView(monthlySummary: monthlySummary, dailySummaries: dailySummaries)
    }

    static var mixedHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let dailySummaries = mixedDailySummaries(calendar: calendar, monthStart: monthStart)
        let monthlySummary = HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: now),
            periodStart: monthStart,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 720,
            measuredIntervalCount: 360,
            totalConsumptionKWh: dailySummaries.compactMap(\.totalConsumptionKWh).reduce(0, +),
            totalCostSEK: dailySummaries.compactMap(\.totalCostSEK).reduce(0, +),
            averageSpotPriceOrePerKWh: 75.5,
            minSpotPriceOrePerKWh: 20.0,
            maxSpotPriceOrePerKWh: 180.0,
            confidence: .partial
        )

        return historyView(monthlySummary: monthlySummary, dailySummaries: dailySummaries)
    }

    private static func historyView(
        monthlySummary: HistoricalEnergySummaryValue,
        dailySummaries: [HistoricalEnergySummaryValue]
    ) -> some View {
        let topCost = Array(dailySummaries
            .filter { $0.totalCostSEK != nil }
            .sorted { ($0.totalCostSEK ?? 0) > ($1.totalCostSEK ?? 0) }
            .prefix(3))
        let topConsumption = Array(dailySummaries
            .filter { $0.totalConsumptionKWh != nil }
            .sorted { ($0.totalConsumptionKWh ?? 0) > ($1.totalConsumptionKWh ?? 0) }
            .prefix(3))

        return HistoryMonthView(
            priceArea: "SE3",
            costProfile: .swedishDefaultEstimate(),
            previewState: .loaded(HistoryMonthData(
                months: [monthlySummary],
                selectedMonth: monthlySummary,
                dailySummaries: dailySummaries,
                topCostDays: topCost,
                topConsumptionDays: topConsumption
            ))
        )
    }

    private static func measuredDailySummaries(
        calendar: Calendar,
        monthStart: Date
    ) -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
            return dailySummary(
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
                return dailySummary(
                    date: date,
                    measuredCount: 24,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .measured
                )
            case 1:
                return dailySummary(
                    date: date,
                    measuredCount: 12,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .partial
                )
            case 2:
                return dailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: Double.random(in: 150...350),
                    confidence: .estimated
                )
            default:
                return dailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: nil,
                    confidence: .priceOnly
                )
            }
        }
    }

    private static func dailySummary(
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