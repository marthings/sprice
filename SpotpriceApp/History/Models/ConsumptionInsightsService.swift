import Foundation

@MainActor
enum ConsumptionInsightsService {
    private static var cache: [String: ConsumptionInsights] = [:]

    static func invalidate() {
        cache.removeAll()
    }

    static func insights(
        for route: ConsumptionInsightsRoute,
        costProfile: CostProfile,
        dailySummaries: [HistoricalEnergySummaryValue],
        historyQuery: (any EnergyHistoryQuerying)?
    ) async -> ConsumptionInsights {
        let calendar = Calendar.energyHistory
        let now = Date()
        let bounds = periodBounds(for: route, now: now, calendar: calendar)

        let intervals = await loadIntervals(for: route, historyQuery: historyQuery)
        let previousIntervals = await loadPreviousIntervals(for: route, historyQuery: historyQuery)
        let cacheKey = key(
            route: route,
            costProfile: costProfile,
            intervals: intervals,
            now: now,
            calendar: calendar
        )
        if let cached = cache[cacheKey] {
            return cached
        }

        let built = await buildDetached(
            intervals: intervals,
            previousIntervals: previousIntervals,
            dailySummaries: dailySummaries,
            costProfile: costProfile,
            periodStart: bounds.start,
            periodEnd: bounds.end,
            now: now,
            periodKind: route.periodKind
        )
        cache[cacheKey] = built
        return built
    }

    static func insights(
        intervals: [HistoricalEnergyIntervalValue],
        dailySummaries: [HistoricalEnergySummaryValue],
        costProfile: CostProfile,
        periodStart: Date,
        periodEnd: Date,
        periodKind: ConsumptionInsightsPeriodKind
    ) async -> ConsumptionInsights {
        let now = Date()
        return await buildDetached(
            intervals: intervals,
            previousIntervals: [],
            dailySummaries: dailySummaries,
            costProfile: costProfile,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            periodKind: periodKind
        )
    }

    private static func buildDetached(
        intervals: [HistoricalEnergyIntervalValue],
        previousIntervals: [HistoricalEnergyIntervalValue],
        dailySummaries: [HistoricalEnergySummaryValue],
        costProfile: CostProfile,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        periodKind: ConsumptionInsightsPeriodKind
    ) async -> ConsumptionInsights {
        await Task.detached(priority: .userInitiated) {
            buildOffMain(
                intervals: intervals,
                previousIntervals: previousIntervals,
                dailySummaries: dailySummaries,
                costProfile: costProfile,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                periodKind: periodKind
            )
        }.value
    }

    nonisolated private static func buildOffMain(
        intervals: [HistoricalEnergyIntervalValue],
        previousIntervals: [HistoricalEnergyIntervalValue],
        dailySummaries: [HistoricalEnergySummaryValue],
        costProfile: CostProfile,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        periodKind: ConsumptionInsightsPeriodKind
    ) -> ConsumptionInsights {
        ConsumptionInsightsBuilder.make(
            intervals: intervals,
            previousIntervals: previousIntervals,
            dailySummaries: dailySummaries,
            costProfile: costProfile,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            periodKind: periodKind,
            factors: .none
        )
    }

    private static func loadIntervals(
        for route: ConsumptionInsightsRoute,
        historyQuery: (any EnergyHistoryQuerying)?
    ) async -> [HistoricalEnergyIntervalValue] {
        switch route.period {
        case .month(let monthKey, _, _):
            return await loadMonthIntervals(monthKey: monthKey, priceArea: route.priceArea, historyQuery: historyQuery)
        case .day(let dayKey, _):
            return (try? historyQuery?.loadDayIntervals(dayKey: dayKey, priceArea: route.priceArea)) ?? []
        }
    }

    private static func loadPreviousIntervals(
        for route: ConsumptionInsightsRoute,
        historyQuery: (any EnergyHistoryQuerying)?
    ) async -> [HistoricalEnergyIntervalValue] {
        switch route.period {
        case .month(_, let previousMonthKey, _):
            guard let previousMonthKey else { return [] }
            return await loadMonthIntervals(monthKey: previousMonthKey, priceArea: route.priceArea, historyQuery: historyQuery)
        case .day:
            return []
        }
    }

    private static func loadMonthIntervals(
        monthKey: String,
        priceArea: String,
        historyQuery: (any EnergyHistoryQuerying)?
    ) async -> [HistoricalEnergyIntervalValue] {
        if let writer = try? EnergyHistoryStores.writer() {
            if let intervals = try? await writer.loadPreferredIntervals(monthKey: monthKey, priceArea: priceArea) {
                return intervals
            }
        }
        return (try? historyQuery?.loadPreferredIntervals(monthKey: monthKey, priceArea: priceArea)) ?? []
    }

    private static func periodBounds(
        for route: ConsumptionInsightsRoute,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        switch route.period {
        case .month(_, _, let periodStart):
            let end = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
            return (periodStart, min(end, now))
        case .day(_, let date):
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, min(end, now))
        }
    }

    private static func key(
        route: ConsumptionInsightsRoute,
        costProfile: CostProfile,
        intervals: [HistoricalEnergyIntervalValue],
        now: Date,
        calendar: Calendar
    ) -> String {
        let lastStart = intervals.last?.intervalStart.timeIntervalSince1970 ?? 0
        let tariff = costProfile.effectTariff.map { "\($0.monthlyPricePerKW)-\($0.model.rawValue)" } ?? "none"
        let bucket: String
        switch route.period {
        case .month(_, _, let periodStart):
            if calendar.isDate(periodStart, equalTo: now, toGranularity: .month) {
                bucket = "h\(calendar.component(.hour, from: now))"
            } else {
                bucket = "closed"
            }
        case .day(_, let date):
            if calendar.isDate(date, inSameDayAs: now) {
                bucket = "h\(calendar.component(.hour, from: now))"
            } else {
                bucket = "closed"
            }
        }
        return "\(route.id)|\(intervals.count)|\(lastStart)|\(tariff)|\(bucket)"
    }
}
