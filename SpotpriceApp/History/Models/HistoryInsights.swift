import Foundation

struct HistoryMonthSnapshot {
    let summary: HistoricalEnergySummaryValue
    let isCurrentMonth: Bool
    let costKr: Double?
    let kWh: Double?
    let paidKrPerKWh: Double?
    let spotOrePerKWh: Double?
    let usedCurrentTariffs: Bool

    var spotKrPerKWh: Double? {
        spotOrePerKWh.map { $0 / 100 }
    }

    var coverageText: String {
        switch summary.dataCoverage {
        case .priceOnly:
            return "Bara spotpris, förbrukning saknas"
        case .estimatedCost:
            return "Kostnad utan mätt förbrukning"
        case .partialConsumption:
            return summary.coverageText(style: .compact)
        case .measuredConsumption:
            return "Mätt förbrukning"
        }
    }
}

struct HistoryMonthComparison {
    let previous: HistoryMonthSnapshot
    let costDeltaKr: Double
    let percentChange: Double?
}

struct HistoryPriceConsumptionSplit {
    let consumptionEffectKr: Double
    let priceEffectKr: Double
    let previousMonthName: String
}

struct HistoryWeekdayAverage: Identifiable {
    let weekday: Int
    let label: String
    let averageCostKr: Double?
    let averageKWh: Double?
    let sampleCount: Int

    var id: Int { weekday }
}

enum HistoryInsights {
    private static let negligibleKr = 0.5

    static func preferredMonthKey(
        from months: [HistoricalEnergySummaryValue],
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> String? {
        let currentKey = EnergyHistoryKey.monthKey(for: now, calendar: calendar)
        return months.first { $0.periodKey != currentKey }?.periodKey
            ?? months.first?.periodKey
    }

    static func previousMonth(
        of selected: HistoricalEnergySummaryValue,
        in months: [HistoricalEnergySummaryValue]
    ) -> HistoricalEnergySummaryValue? {
        months
            .filter { $0.periodStart < selected.periodStart }
            .max { $0.periodStart < $1.periodStart }
    }

    static func snapshot(
        summary: HistoricalEnergySummaryValue,
        costProfile: CostProfile,
        liveMonthlyConsumption: ConsumptionData?,
        livePreciseCost: PreciseMonthlyCost?,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> HistoryMonthSnapshot {
        let isCurrent = summary.periodKey == EnergyHistoryKey.monthKey(for: now, calendar: calendar)
        let kWh = isCurrent
            ? (liveMonthlyConsumption?.totalKWh ?? summary.totalConsumptionKWh)
            : summary.totalConsumptionKWh
        let spotOre = summary.averageSpotPriceOrePerKWh
        let cost = monthCost(
            summary: summary,
            isCurrentMonth: isCurrent,
            kWh: kWh,
            spotOre: spotOre,
            costProfile: costProfile,
            livePreciseCost: livePreciseCost,
            now: now,
            calendar: calendar
        )
        let paid = paidKrPerKWh(costKr: cost.amount, kWh: kWh)

        return HistoryMonthSnapshot(
            summary: summary,
            isCurrentMonth: isCurrent,
            costKr: cost.amount,
            kWh: kWh,
            paidKrPerKWh: paid,
            spotOrePerKWh: spotOre,
            usedCurrentTariffs: cost.usedCurrentTariffs
        )
    }

    static func comparison(
        current: HistoryMonthSnapshot,
        previous: HistoryMonthSnapshot?
    ) -> HistoryMonthComparison? {
        guard let previous,
              let currentCost = current.costKr,
              let previousCost = previous.costKr else {
            return nil
        }
        let delta = currentCost - previousCost
        let percent: Double?
        if abs(previousCost) >= negligibleKr {
            percent = (delta / previousCost) * 100
        } else {
            percent = nil
        }
        return HistoryMonthComparison(
            previous: previous,
            costDeltaKr: delta,
            percentChange: percent
        )
    }

    static func priceConsumptionSplit(
        current: HistoryMonthSnapshot,
        previous: HistoryMonthSnapshot?
    ) -> HistoryPriceConsumptionSplit? {
        guard let previous,
              let currentKWh = current.kWh, currentKWh > 0,
              let previousKWh = previous.kWh, previousKWh > 0,
              let currentPaid = current.paidKrPerKWh,
              let previousPaid = previous.paidKrPerKWh else {
            return nil
        }

        return HistoryPriceConsumptionSplit(
            consumptionEffectKr: (currentKWh - previousKWh) * previousPaid,
            priceEffectKr: currentKWh * (currentPaid - previousPaid),
            previousMonthName: AppFormatters.monthName(previous.summary.periodStart)
        )
    }

    static func weekdayAverages(
        from days: [MonthDayCost],
        calendar: Calendar = .energyHistory
    ) -> [HistoryWeekdayAverage] {
        let orderedWeekdays = weekdayOrder(calendar: calendar)
        let labels = weekdayLabels(calendar: calendar)
        let grouped = Dictionary(grouping: days) { calendar.component(.weekday, from: $0.date) }

        return orderedWeekdays.map { weekday in
            let samples = grouped[weekday] ?? []
            let costs = samples.compactMap(\.costKr)
            let kWhs = samples.compactMap(\.kWh)
            return HistoryWeekdayAverage(
                weekday: weekday,
                label: labels[weekday] ?? "",
                averageCostKr: average(of: costs),
                averageKWh: average(of: kWhs),
                sampleCount: costs.count
            )
        }
    }

    static func lastDayOfMonth(
        containing date: Date,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return date
        }
        let lastDay = interval.end.addingTimeInterval(-1)
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return min(lastDay, now)
        }
        return lastDay
    }

    static func signedKr(_ value: Double) -> String {
        let amount = AppFormatters.wholeNumber(abs(value))
        if value > negligibleKr {
            return "+\(amount) kr"
        }
        if value < -negligibleKr {
            return "-\(amount) kr"
        }
        return "\(amount) kr"
    }

    static func signedPercent(_ value: Double) -> String {
        let amount = AppFormatters.wholeNumber(abs(value))
        if value > 0.5 {
            return "+\(amount) %"
        }
        if value < -0.5 {
            return "-\(amount) %"
        }
        return "\(amount) %"
    }

    static func comparisonSentence(deltaKr: Double, previousMonthName: String, percent: Double?) -> String {
        let amount = AppFormatters.wholeNumber(abs(deltaKr))
        let percentText = percent.map { " (\(signedPercent($0)))" } ?? ""
        if deltaKr > negligibleKr {
            return "\(amount) kr mer än \(previousMonthName)\(percentText)"
        }
        if deltaKr < -negligibleKr {
            return "\(amount) kr mindre än \(previousMonthName)\(percentText)"
        }
        return "Ungefär samma kostnad som \(previousMonthName)"
    }

    static func splitTitle(consumptionEffectKr: Double, priceEffectKr: Double) -> String {
        let total = consumptionEffectKr + priceEffectKr
        if total > negligibleKr {
            return "Därför blev det dyrare"
        }
        if total < -negligibleKr {
            return "Därför blev det billigare"
        }
        return "Så här skiljer sig månaderna"
    }

    static func consumptionEffectLabel(_ value: Double) -> String {
        value >= 0 ? "Mer el" : "Mindre el"
    }

    static func priceEffectLabel(_ value: Double) -> String {
        value >= 0 ? "Högre pris" : "Lägre pris"
    }

    static func splitSentence(consumptionEffectKr: Double, priceEffectKr: Double) -> String {
        let moreUse = consumptionEffectKr > negligibleKr
        let lessUse = consumptionEffectKr < -negligibleKr
        let higherPrice = priceEffectKr > negligibleKr
        let lowerPrice = priceEffectKr < -negligibleKr

        switch (moreUse, lessUse, higherPrice, lowerPrice) {
        case (true, false, true, false):
            return "Du använde mer el, och den var dyrare per kWh."
        case (true, false, false, true):
            return "Du använde mer el. Priset per kWh var lägre."
        case (false, true, true, false):
            return "Du använde mindre el. Priset per kWh var högre."
        case (false, true, false, true):
            return "Du använde mindre el, och den var billigare per kWh."
        case (true, false, false, false):
            return "Du använde mer el. Priset per kWh var ungefär detsamma."
        case (false, true, false, false):
            return "Du använde mindre el. Priset per kWh var ungefär detsamma."
        case (false, false, true, false):
            return "Du använde ungefär lika mycket el. Priset per kWh var högre."
        case (false, false, false, true):
            return "Du använde ungefär lika mycket el. Priset per kWh var lägre."
        default:
            return "Förbrukning och pris per kWh var ungefär desamma som månaden före."
        }
    }

    static func weekdayPatternIsSparse(_ averages: [HistoryWeekdayAverage]) -> Bool {
        let sampledDays = averages.reduce(0) { $0 + $1.sampleCount }
        let weekdaysWithData = averages.filter { $0.sampleCount > 0 }.count
        return sampledDays < 7 || weekdaysWithData < 5
    }

    static func emptyHistoryMessage(hasProvider: Bool) -> String {
        if hasProvider {
            return "Historik fylls på när appen har hämtat priser. Förbrukningen har inte kommit in ännu. När den finns ser du vad månaden kostat."
        }
        return "Historik fylls på när appen har hämtat priser. Gå till Inställningar och lägg till förbrukning. Då kan du se vad månaden kostat."
    }

    static func missingConsumptionMessage(hasProvider: Bool) -> String {
        if hasProvider {
            return "Förbrukningen för den här månaden har inte kommit in ännu. När den finns ser du vad den kostat."
        }
        return "Gå till Inställningar och lägg till förbrukning. Då kan du se vad månaden kostat."
    }

    private static func monthCost(
        summary: HistoricalEnergySummaryValue,
        isCurrentMonth: Bool,
        kWh: Double?,
        spotOre: Double?,
        costProfile: CostProfile,
        livePreciseCost: PreciseMonthlyCost?,
        now: Date,
        calendar: Calendar
    ) -> (amount: Double?, usedCurrentTariffs: Bool) {
        let service = TotalCostService.shared

        if isCurrentMonth {
            if let livePreciseCost, livePreciseCost.totalKWh > 0 {
                let effectiveSpot = (livePreciseCost.totalCostKr / livePreciseCost.totalKWh) * 100
                return (
                    service.calculateTotalCost(
                        kWh: livePreciseCost.totalKWh,
                        spotPriceOre: effectiveSpot,
                        profile: costProfile,
                        hoursInPeriod: elapsedHours(from: summary.periodStart, now: now, calendar: calendar)
                    ).totalKr,
                    true
                )
            }
            if let kWh, kWh > 0, let spotOre {
                return (
                    service.calculateTotalCost(
                        kWh: kWh,
                        spotPriceOre: spotOre,
                        profile: costProfile,
                        hoursInPeriod: elapsedHours(from: summary.periodStart, now: now, calendar: calendar)
                    ).totalKr,
                    true
                )
            }
            return (summary.totalCostSEK, false)
        }

        if let stored = summary.totalCostSEK {
            return (stored, false)
        }
        if let kWh, kWh > 0, let spotOre {
            return (
                service.calculateTotalCost(
                    kWh: kWh,
                    spotPriceOre: spotOre,
                    profile: costProfile,
                    hoursInPeriod: hoursInMonth(containing: summary.periodStart, calendar: calendar)
                ).totalKr,
                true
            )
        }
        return (nil, false)
    }

    private static func hoursInMonth(containing date: Date, calendar: Calendar) -> Double {
        let days = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        return Double(days * 24)
    }

    private static func elapsedHours(from monthStart: Date, now: Date, calendar: Calendar) -> Double {
        let start = calendar.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
        return max(now.timeIntervalSince(start) / 3600, 1 / 60)
    }

    private static func paidKrPerKWh(costKr: Double?, kWh: Double?) -> Double? {
        guard let costKr, let kWh, kWh > 0 else { return nil }
        return costKr / kWh
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func weekdayOrder(calendar: Calendar) -> [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private static func weekdayLabels(calendar: Calendar) -> [Int: String] {
        let symbols = calendar.shortWeekdaySymbols
        var labels: [Int: String] = [:]
        for (index, symbol) in symbols.enumerated() {
            labels[index + 1] = symbol.lowercased(with: AppFormatters.swedishLocale)
        }
        return labels
    }
}
