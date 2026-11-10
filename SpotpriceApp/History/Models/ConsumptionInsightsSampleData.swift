#if DEBUG
import Foundation

enum ConsumptionInsightsSampleData {
    static let priceArea = "SE3"

    static var isLaunchPreviewEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains { argument in
            argument.hasPrefix("-InsightsPreview") || argument.hasPrefix("-TemperaturePreview")
        }
    }

    /// Shifts the October sample into the current month and stops at last night, so the simulator can show the cards.
    static func previewIntervals(now: Date = Date(), calendar: Calendar = .energyHistory) -> [HistoricalEnergyIntervalValue] {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return monthIntervals()
        }
        let offset = currentStart.timeIntervalSince(monthStart)
        let cutoff = previewMeasuredThrough(now: now, calendar: calendar)
        return monthIntervals().compactMap { interval in
            let start = interval.intervalStart.addingTimeInterval(offset)
            let end = interval.intervalEnd.addingTimeInterval(offset)
            guard start < cutoff else { return nil }
            return HistoricalEnergyIntervalValue(
                id: interval.id,
                intervalStart: start,
                intervalEnd: end,
                spotPriceOrePerKWh: interval.spotPriceOrePerKWh,
                consumptionKWh: interval.consumptionKWh,
                energyCostSEK: interval.energyCostSEK,
                gridCostSEK: interval.gridCostSEK,
                taxCostSEK: interval.taxCostSEK,
                vatCostSEK: interval.vatCostSEK,
                totalCostSEK: interval.totalCostSEK
            )
        }
    }

    static func previewMeasuredThrough(now: Date = Date(), calendar: Calendar = .energyHistory) -> Date {
        let today = calendar.startOfDay(for: now)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let twentyThree = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) {
            return twentyThree
        }
        return now
    }

    static func previewDailySummaries(now: Date = Date(), calendar: Calendar = .energyHistory) -> [HistoricalEnergySummaryValue] {
        let grouped = Dictionary(grouping: previewIntervals(now: now, calendar: calendar)) {
            calendar.startOfDay(for: $0.intervalStart)
        }
        return grouped.keys.sorted().map { day in
            let items = grouped[day] ?? []
            let kWh = items.reduce(0.0) { $0 + ($1.consumptionKWh ?? 0) }
            let cost = items.reduce(0.0) { $0 + ($1.totalCostSEK ?? 0) }
            let spots = items.map(\.spotPriceOrePerKWh)
            return HistoricalEnergySummaryValue(
                id: UUID(),
                periodKey: EnergyHistoryKey.dayKey(for: day, calendar: calendar),
                periodStart: day,
                priceArea: priceArea,
                providerID: "preview",
                intervalCount: items.count,
                measuredIntervalCount: items.count,
                totalConsumptionKWh: kWh,
                totalCostSEK: cost,
                averageSpotPriceOrePerKWh: spots.isEmpty ? nil : spots.reduce(0, +) / Double(spots.count),
                minSpotPriceOrePerKWh: spots.min(),
                maxSpotPriceOrePerKWh: spots.max(),
                confidence: .measured
            )
        }
    }

    static func previewMonthSummary(now: Date = Date(), calendar: Calendar = .energyHistory) -> HistoricalEnergySummaryValue {
        let days = previewDailySummaries(now: now, calendar: calendar)
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let intervals = previewIntervals(now: now, calendar: calendar)
        let spots = intervals.map(\.spotPriceOrePerKWh)
        return HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: start, calendar: calendar),
            periodStart: start,
            priceArea: priceArea,
            providerID: "preview",
            intervalCount: intervals.count,
            measuredIntervalCount: intervals.count,
            totalConsumptionKWh: days.reduce(0.0) { $0 + ($1.totalConsumptionKWh ?? 0) },
            totalCostSEK: days.reduce(0.0) { $0 + ($1.totalCostSEK ?? 0) },
            averageSpotPriceOrePerKWh: spots.isEmpty ? nil : spots.reduce(0, +) / Double(spots.count),
            minSpotPriceOrePerKWh: spots.min(),
            maxSpotPriceOrePerKWh: spots.max(),
            confidence: .measured
        )
    }

    static func previewPreviousDailySummaries(now: Date = Date(), calendar: Calendar = .energyHistory) -> [HistoricalEnergySummaryValue] {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start,
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentStart) else {
            return []
        }
        let current = previewDailySummaries(now: now, calendar: calendar)
        return current.compactMap { day in
            let offset = day.periodStart.timeIntervalSince(currentStart)
            let date = previousStart.addingTimeInterval(offset)
            guard calendar.isDate(date, equalTo: previousStart, toGranularity: .month) else { return nil }
            return HistoricalEnergySummaryValue(
                id: UUID(),
                periodKey: EnergyHistoryKey.dayKey(for: date, calendar: calendar),
                periodStart: date,
                priceArea: priceArea,
                providerID: "preview",
                intervalCount: day.intervalCount,
                measuredIntervalCount: day.measuredIntervalCount,
                totalConsumptionKWh: (day.totalConsumptionKWh ?? 0) * 0.92,
                totalCostSEK: (day.totalCostSEK ?? 0) * 0.92,
                averageSpotPriceOrePerKWh: day.averageSpotPriceOrePerKWh,
                minSpotPriceOrePerKWh: day.minSpotPriceOrePerKWh,
                maxSpotPriceOrePerKWh: day.maxSpotPriceOrePerKWh,
                confidence: .measured
            )
        }
    }

    static func previewPreviousMonthSummary(now: Date = Date(), calendar: Calendar = .energyHistory) -> HistoricalEnergySummaryValue? {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start,
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentStart) else {
            return nil
        }
        let days = previewPreviousDailySummaries(now: now, calendar: calendar)
        guard !days.isEmpty else { return nil }
        return HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: previousStart, calendar: calendar),
            periodStart: previousStart,
            priceArea: priceArea,
            providerID: "preview",
            intervalCount: days.reduce(0) { $0 + $1.intervalCount },
            measuredIntervalCount: days.reduce(0) { $0 + $1.measuredIntervalCount },
            totalConsumptionKWh: days.reduce(0.0) { $0 + ($1.totalConsumptionKWh ?? 0) },
            totalCostSEK: days.reduce(0.0) { $0 + ($1.totalCostSEK ?? 0) },
            averageSpotPriceOrePerKWh: days.compactMap(\.averageSpotPriceOrePerKWh).first,
            minSpotPriceOrePerKWh: days.compactMap(\.minSpotPriceOrePerKWh).min(),
            maxSpotPriceOrePerKWh: days.compactMap(\.maxSpotPriceOrePerKWh).max(),
            confidence: .measured
        )
    }

    /// Example household for the fit: 20 kWh per day plus 1 kWh per degree below 17 °C, using real temperatures.
    static func previewFitConsumption(temperatures: [Date: Double], skipping: Set<Date>, calendar: Calendar) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for (day, temp) in temperatures {
            let start = calendar.startOfDay(for: day)
            if skipping.contains(start) { continue }
            let month = calendar.component(.month, from: start)
            guard [1, 2, 6, 7, 8].contains(month) else { continue }
            result[start] = 20 + TemperatureAdjustment.heatingDegreeDays(meanTempC: temp)
        }
        return result
    }

        static func octoberMonthRoute() -> ConsumptionInsightsRoute {
        ConsumptionInsightsRoute(
            period: .month(
                monthKey: EnergyHistoryKey.monthKey(for: monthStart),
                previousMonthKey: EnergyHistoryKey.monthKey(for: previousMonthStart),
                periodStart: monthStart
            ),
            priceArea: priceArea
        )
    }

    static func fridayRoute() -> ConsumptionInsightsRoute {
        ConsumptionInsightsRoute(
            period: .day(dayKey: EnergyHistoryKey.dayKey(for: friday), date: friday),
            priceArea: priceArea
        )
    }

    static func monthInsights(includeEffectTariff: Bool = true) -> ConsumptionInsights {
        _ = ConsumptionInsightsBuilder.debugVerifyAlgorithms()
        return ConsumptionInsightsBuilder.make(
            intervals: monthIntervals(),
            previousIntervals: previousMonthNightIntervals(),
            dailySummaries: [],
            costProfile: costProfile(includeEffectTariff: includeEffectTariff),
            periodStart: monthStart,
            periodEnd: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            now: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            periodKind: .month,
            includeHypotheticalEffectTariff: includeEffectTariff
        )
    }

    static func dayInsights() -> ConsumptionInsights {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: friday)!
        return ConsumptionInsightsBuilder.make(
            intervals: intervals(forDay: friday, includeOven: true, includeCharge: false),
            previousIntervals: [],
            dailySummaries: [],
            costProfile: costProfile(includeEffectTariff: true),
            periodStart: friday,
            periodEnd: dayEnd,
            now: dayEnd,
            periodKind: .day
        )
    }

    static func dailyOnlyInsights() -> ConsumptionInsights {
        ConsumptionInsightsBuilder.make(
            intervals: [],
            previousIntervals: [],
            dailySummaries: dailySummaries(),
            costProfile: costProfile(includeEffectTariff: false),
            periodStart: monthStart,
            periodEnd: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            now: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            periodKind: .month
        )
    }

    private static var calendar: Calendar { .energyHistory }

    private static var monthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
    }

    private static var previousMonthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    }

    private static var friday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
    }

    private static var saturday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 17))!
    }

    private static func costProfile(includeEffectTariff: Bool) -> CostProfile {
        let tariff = includeEffectTariff
            ? EffectTariff(monthlyPricePerKW: 50, model: .singlePeak, activeHours: .allHours)
            : nil
        return CostProfile.swedishDefaultEstimate().settingEffectTariff(tariff)
    }

    private static func monthIntervals() -> [HistoricalEnergyIntervalValue] {
        var result: [HistoricalEnergyIntervalValue] = []
        for dayOffset in 0..<31 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) else {
                continue
            }
            let isFriday = calendar.isDate(day, inSameDayAs: friday)
            let isSaturday = calendar.isDate(day, inSameDayAs: saturday)
            result.append(contentsOf: intervals(forDay: day, includeOven: isFriday, includeCharge: isSaturday))
        }
        return result
    }

    private static func previousMonthNightIntervals() -> [HistoricalEnergyIntervalValue] {
        (0..<5).flatMap { dayOffset -> [HistoricalEnergyIntervalValue] in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: previousMonthStart) else {
                return []
            }
            return (0..<20).map { index in
                interval(
                    start: day.addingTimeInterval(Double(index) * 900),
                    kWh: 0.10,
                    spotOre: 25
                )
            }
        }
    }

    private static func intervals(
        forDay day: Date,
        includeOven: Bool,
        includeCharge: Bool
    ) -> [HistoricalEnergyIntervalValue] {
        (0..<96).map { index in
            let start = day.addingTimeInterval(Double(index) * 900)
            let hour = calendar.component(.hour, from: start)
            let kWh: Double
            if hour < 5 {
                kWh = 0.08
            } else if includeCharge && hour >= 10 && hour < 14 {
                kWh = 0.60
            } else if includeOven && hour == 17 {
                kWh = 2.0
            } else if hour >= 7 && hour < 9 {
                kWh = 0.28
            } else if hour >= 17 && hour < 22 {
                kWh = 0.12
            } else {
                kWh = 0.12
            }
            let spot: Double
            if hour < 6 {
                spot = 22
            } else if hour >= 17 {
                spot = 155
            } else {
                spot = 70
            }
            return interval(start: start, kWh: kWh, spotOre: spot)
        }
    }

    private static func interval(start: Date, kWh: Double, spotOre: Double) -> HistoricalEnergyIntervalValue {
        let priceKr = (spotOre / 100) + 0.80
        return HistoricalEnergyIntervalValue(
            id: UUID(),
            intervalStart: start,
            intervalEnd: start.addingTimeInterval(900),
            spotPriceOrePerKWh: spotOre,
            consumptionKWh: kWh,
            energyCostSEK: nil,
            gridCostSEK: nil,
            taxCostSEK: nil,
            vatCostSEK: nil,
            totalCostSEK: kWh * priceKr
        )
    }

    private static func dailySummaries() -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
            let kWh = 28.0 + Double(dayOffset % 5) * 3
            return HistoricalEnergySummaryValue(
                id: UUID(),
                periodKey: EnergyHistoryKey.dayKey(for: date),
                periodStart: date,
                priceArea: priceArea,
                providerID: "tibber",
                intervalCount: 24,
                measuredIntervalCount: 24,
                totalConsumptionKWh: kWh,
                totalCostSEK: kWh * 1.6,
                averageSpotPriceOrePerKWh: 70,
                minSpotPriceOrePerKWh: 20,
                maxSpotPriceOrePerKWh: 160,
                confidence: .measured
            )
        }
    }
}
#endif
