import Foundation

struct HistoryDayRoute: Hashable, Identifiable {
    let dayKey: String
    let date: Date

    var id: String { dayKey }
}

struct HistoryHourCost: Identifiable, Equatable {
    let start: Date
    let costKr: Double?
    let kWh: Double?
    let spotOrePerKWh: Double?

    var id: Date { start }

    var hourRangeLabel: String {
        let hour = Calendar.energyHistory.component(.hour, from: start)
        return "\(hour)-\(hour + 1)"
    }
}

struct HistoryDayCostSplit: Equatable {
    let energyKr: Double
    let gridKr: Double
    let taxKr: Double
    let vatKr: Double
    let usedCurrentTariffs: Bool

    var totalKr: Double {
        energyKr + gridKr + taxKr + vatKr
    }

    var hasValues: Bool {
        energyKr > 0 || gridKr > 0 || taxKr > 0 || vatKr > 0
    }
}

struct HistoryDaySnapshot {
    let date: Date
    let costKr: Double?
    let kWh: Double?
    let paidKrPerKWh: Double?
    let hours: [HistoryHourCost]
    let costHours: [HistoryHourCost]
    let spotHours: [HistoryHourCost]
    let expensiveHoursUsed: [HistoryHourCost]
    let split: HistoryDayCostSplit?
    let isIncomplete: Bool
    let hasMeasuredUse: Bool
}

enum HistoryDayInsights {
    static func snapshot(
        date: Date,
        dailySummary: HistoricalEnergySummaryValue?,
        intervals: [HistoricalEnergyIntervalValue],
        costProfile: CostProfile,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> HistoryDaySnapshot {
        // A day lies inside one agreement version (versions start at midnight).
        let costProfile = HistoryPricing.liveProfile(at: calendar.startOfDay(for: date), current: costProfile)
        let hours = hourCosts(
            from: intervals,
            dayDate: date,
            costProfile: costProfile,
            now: now,
            calendar: calendar
        )
        let measuredHours = hours.filter { hour in
            (hour.kWh ?? 0) > 0
        }
        let intervalKWh = sum(measuredHours.compactMap(\.kWh))
        let intervalCost = sum(measuredHours.compactMap(\.costKr))
        let kWh = positive(intervalKWh) ?? dailySummary?.totalConsumptionKWh
        let cost = resolvedDayCost(
            intervalCost: intervalCost,
            kWh: kWh,
            summary: dailySummary,
            costProfile: costProfile,
            date: date,
            now: now,
            calendar: calendar
        )
        let paid: Double?
        if let cost, let kWh, kWh > 0 {
            paid = cost / kWh
        } else {
            paid = dailySummary?.averageTotalCostSEKPerKWh
        }

        return HistoryDaySnapshot(
            date: date,
            costKr: cost,
            kWh: kWh,
            paidKrPerKWh: paid,
            hours: hours,
            costHours: hours.filter { $0.costKr != nil },
            spotHours: hours.filter { $0.spotOrePerKWh != nil },
            expensiveHoursUsed: Array(
                measuredHours
                    .filter { ($0.costKr ?? 0) > 0 }
                    .sorted { ($0.costKr ?? 0) > ($1.costKr ?? 0) }
                    .prefix(3)
            ),
            split: costSplit(from: intervals, kWh: kWh, summary: dailySummary, costProfile: costProfile, date: date, now: now, calendar: calendar),
            isIncomplete: isIncompleteDay(date: date, summary: dailySummary, now: now, calendar: calendar),
            hasMeasuredUse: !measuredHours.isEmpty
        )
    }

    private static func hourCosts(
        from intervals: [HistoricalEnergyIntervalValue],
        dayDate: Date,
        costProfile: CostProfile,
        now: Date,
        calendar: Calendar
    ) -> [HistoryHourCost] {
        let grouped = Dictionary(grouping: intervals) { interval in
            calendar.dateInterval(of: .hour, for: interval.intervalStart)?.start ?? interval.intervalStart
        }
        let dayStart = calendar.startOfDay(for: dayDate)
        let isToday = calendar.isDate(dayDate, inSameDayAs: now)
        let service = TotalCostService.shared
        var hours: [HistoryHourCost] = []

        for hourIndex in 0..<24 {
            guard let start = calendar.date(byAdding: .hour, value: hourIndex, to: dayStart) else {
                continue
            }
            if isToday && start > now {
                break
            }

            let items = grouped[start] ?? []
            let kWh = sum(items.compactMap(\.consumptionKWh))
            let storedCost = sum(items.compactMap(\.totalCostSEK))
            let spot = average(items.map(\.spotPriceOrePerKWh))
            let cost: Double?
            if let storedCost, storedCost > 0 {
                cost = storedCost
            } else if let kWh, kWh > 0, let spot {
                cost = service.calculateTotalCost(
                    kWh: kWh,
                    spotPriceOre: spot,
                    profile: costProfile,
                    hoursInPeriod: 1
                ).totalKr
            } else {
                cost = nil
            }

            hours.append(
                HistoryHourCost(
                    start: start,
                    costKr: cost,
                    kWh: kWh,
                    spotOrePerKWh: spot
                )
            )
        }

        return hours
    }

    private static func resolvedDayCost(
        intervalCost: Double?,
        kWh: Double?,
        summary: HistoricalEnergySummaryValue?,
        costProfile: CostProfile,
        date: Date,
        now: Date,
        calendar: Calendar
    ) -> Double? {
        if let intervalCost, intervalCost > 0 {
            return intervalCost
        }
        if let kWh, kWh > 0, let spot = summary?.averageSpotPriceOrePerKWh {
            let isToday = calendar.isDate(date, inSameDayAs: now)
            let hoursInPeriod = isToday
                ? max(now.timeIntervalSince(calendar.startOfDay(for: date)) / 3600, 1 / 60)
                : 24
            return TotalCostService.shared.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spot,
                profile: costProfile,
                hoursInPeriod: hoursInPeriod
            ).totalKr
        }
        return summary?.totalCostSEK
    }

    private static func costSplit(
        from intervals: [HistoricalEnergyIntervalValue],
        kWh: Double?,
        summary: HistoricalEnergySummaryValue?,
        costProfile: CostProfile,
        date: Date,
        now: Date,
        calendar: Calendar
    ) -> HistoryDayCostSplit? {
        let measured = intervals.filter { ($0.consumptionKWh ?? 0) > 0 }
        let completeSplits = measured.filter {
            $0.energyCostSEK != nil && $0.gridCostSEK != nil && $0.taxCostSEK != nil && $0.vatCostSEK != nil
        }
        if !measured.isEmpty && completeSplits.count == measured.count {
            return HistoryDayCostSplit(
                energyKr: completeSplits.compactMap(\.energyCostSEK).reduce(0, +),
                gridKr: completeSplits.compactMap(\.gridCostSEK).reduce(0, +),
                taxKr: completeSplits.compactMap(\.taxCostSEK).reduce(0, +),
                vatKr: completeSplits.compactMap(\.vatCostSEK).reduce(0, +),
                usedCurrentTariffs: false
            )
        }

        guard let kWh, kWh > 0, let spot = summary?.averageSpotPriceOrePerKWh ?? average(intervals.map(\.spotPriceOrePerKWh)) else {
            return nil
        }

        let isToday = calendar.isDate(date, inSameDayAs: now)
        let hoursInPeriod = isToday
            ? max(now.timeIntervalSince(calendar.startOfDay(for: date)) / 3600, 1 / 60)
            : 24
        let cost = TotalCostService.shared.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: spot,
            profile: costProfile,
            hoursInPeriod: hoursInPeriod
        )
        return HistoryDayCostSplit(
            energyKr: cost.providerTotalKr,
            gridKr: cost.gridTotalKr,
            taxKr: cost.taxesAndFeesKr,
            vatKr: cost.vatKr,
            usedCurrentTariffs: true
        )
    }

    private static func isIncompleteDay(
        date: Date,
        summary: HistoricalEnergySummaryValue?,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        if calendar.isDate(date, inSameDayAs: now) {
            return true
        }
        if let summary, summary.hasMissingConsumptionIntervals {
            return true
        }
        return false
    }

    private static func sum(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
