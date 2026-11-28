import Foundation

@MainActor
enum ConsumptionInsightsService {
    private static var cache: [String: ConsumptionInsights] = [:]

    static func invalidate() {
        cache.removeAll()
    }

    static var includeElectricCarGuess: Bool {
        if ConsumptionSettings.shared.hasElectricCar {
            return true
        }
#if DEBUG
        return ConsumptionInsightsSampleData.isElectricCarPreviewEnabled
#else
        return false
#endif
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

        let includeHypotheticalEffectTariff = ConsumptionSettings.shared.includeHypotheticalEffectTariff
        let includeElectricCarGuess = Self.includeElectricCarGuess
        let intervals = await loadIntervals(for: route, historyQuery: historyQuery)
        let lastMeasured = [
            SameDayMonthComparison.lastMeasuredDay(fromIntervals: intervals),
            SameDayMonthComparison.lastMeasuredDay(
                monthStart: bounds.start,
                dailySummaries: dailySummaries,
                calendar: calendar
            )
        ].compactMap { $0 }.max()
            ?? (calendar.isDate(bounds.start, equalTo: now, toGranularity: .month) ? now : nil)
        let previousIntervals = SameDayMonthComparison.restrictingPreviousIntervals(
            await loadPreviousIntervals(for: route, historyQuery: historyQuery),
            lastMeasuredInCurrent: lastMeasured,
            currentMonthStart: bounds.start,
            now: now,
            calendar: calendar
        )
        let cacheKey = key(
            route: route,
            costProfile: costProfile,
            intervals: intervals,
            previousIntervals: previousIntervals,
            includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
            includeElectricCarGuess: includeElectricCarGuess,
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
            periodKind: route.periodKind,
            includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
            includeElectricCarGuess: includeElectricCarGuess
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
            periodKind: periodKind,
            includeHypotheticalEffectTariff: ConsumptionSettings.shared.includeHypotheticalEffectTariff,
            includeElectricCarGuess: includeElectricCarGuess
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
        periodKind: ConsumptionInsightsPeriodKind,
        includeHypotheticalEffectTariff: Bool,
        includeElectricCarGuess: Bool
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
                periodKind: periodKind,
                includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
                includeElectricCarGuess: includeElectricCarGuess
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
        periodKind: ConsumptionInsightsPeriodKind,
        includeHypotheticalEffectTariff: Bool,
        includeElectricCarGuess: Bool
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
            includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
            includeElectricCarGuess: includeElectricCarGuess,
            factors: .none
        )
    }

    private static func loadIntervals(
        for route: ConsumptionInsightsRoute,
        historyQuery: (any EnergyHistoryQuerying)?
    ) async -> [HistoricalEnergyIntervalValue] {
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            return previewIntervals(for: route)
        }
#endif
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

#if DEBUG
    private static func previewIntervals(for route: ConsumptionInsightsRoute) -> [HistoricalEnergyIntervalValue] {
        let intervals = ConsumptionInsightsSampleData.previewIntervals()
        let calendar = Calendar.energyHistory
        switch route.period {
        case .month(_, _, let periodStart):
            return intervals.filter { calendar.isDate($0.intervalStart, equalTo: periodStart, toGranularity: .month) }
        case .day(_, let date):
            return intervals.filter { calendar.isDate($0.intervalStart, inSameDayAs: date) }
        }
    }
#endif

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
        previousIntervals: [HistoricalEnergyIntervalValue],
        includeHypotheticalEffectTariff: Bool,
        includeElectricCarGuess: Bool,
        now: Date,
        calendar: Calendar
    ) -> String {
        let lastStart = intervals.last?.intervalStart.timeIntervalSince1970 ?? 0
        let previousLast = previousIntervals.last?.intervalStart.timeIntervalSince1970 ?? 0
        let tariff = costProfile.effectTariff.map { "\($0.monthlyPricePerKW)-\($0.model.rawValue)" } ?? "none"
        let effectFlag = includeHypotheticalEffectTariff ? "effectOn" : "effectOff"
        let evFlag = includeElectricCarGuess ? "evOn" : "evOff"
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
        return "\(route.id)|\(intervals.count)|\(lastStart)|\(previousIntervals.count)|\(previousLast)|\(tariff)|\(effectFlag)|\(evFlag)|\(bucket)"
    }
}
