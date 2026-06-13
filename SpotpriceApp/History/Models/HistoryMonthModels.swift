import Foundation

enum HistoryMonthViewMode: Equatable {
    case chart
    case table
}

enum HistoryMonthLoadState {
    case loading
    case loaded(HistoryMonthData)
    case failed(String)
}

struct HistoryMonthData {
    let months: [HistoricalEnergySummaryValue]
    let selectedMonth: HistoricalEnergySummaryValue?
    let dailySummaries: [HistoricalEnergySummaryValue]
    let topCostDays: [HistoricalEnergySummaryValue]
    let topConsumptionDays: [HistoricalEnergySummaryValue]
}

enum HistoryMonthFormatting {
    static func isCurrentMonth(
        _ summary: HistoricalEnergySummaryValue,
        calendar: Calendar = .energyHistory
    ) -> Bool {
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let summaryMonth = calendar.component(.month, from: summary.periodStart)
        let summaryYear = calendar.component(.year, from: summary.periodStart)
        return summaryYear == currentYear && summaryMonth == currentMonth
    }

    static func topCostValue(
        for summary: HistoricalEnergySummaryValue,
        isCurrentMonth: Bool,
        costProfile: CostProfile
    ) -> (String, String)? {
        if isCurrentMonth,
           let kWh = summary.totalConsumptionKWh,
           kWh > 0,
           let spot = summary.averageSpotPriceOrePerKWh {
            let service = TotalCostService()
            let cost = service.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spot,
                profile: costProfile,
                hoursInPeriod: 24
            ).totalKr
            return (AppFormatters.wholeNumber(cost), "kr")
        }
        return summary.totalCostSEK.map { (AppFormatters.wholeNumber($0), "kr") }
    }

    static func topConsumptionValue(
        for summary: HistoricalEnergySummaryValue
    ) -> (String, String)? {
        summary.totalConsumptionKWh.map { (AppFormatters.kWhValue($0), "kWh") }
    }

    static func primaryDayValue(
        for summary: HistoricalEnergySummaryValue
    ) -> (String, String)? {
        if let cost = summary.totalCostSEK {
            return (AppFormatters.wholeNumber(cost), "kr")
        }
        if let consumption = summary.totalConsumptionKWh {
            return (AppFormatters.kWhValue(consumption), "kWh")
        }
        return summary.averageSpotPriceOrePerKWh.map { (AppFormatters.oreValue($0), "öre") }
    }
}