import Foundation

struct HistoryMonthSnapshot {
    let summary: HistoricalEnergySummaryValue
    let isCurrentMonth: Bool
    let costKr: Double?
    let kWh: Double?
    let paidKrPerKWh: Double?
    let spotOrePerKWh: Double?
    let usedCurrentTariffs: Bool
    /// Cost split by component, when the total was calculated from the cost profile.
    /// Its total is exactly `costKr`.
    var costParts: EnhancedCost? = nil
    var costProfile: CostProfile? = nil
    /// The spot price (öre/kWh, excluding VAT) that the cost was calculated with.
    var spotBasisOrePerKWh: Double? = nil
    /// The part of `costKr` that does not depend on how much electricity was used: the grid
    /// monthly fee and the retailer's monthly fee, for the days the cost covers. Nil when unknown.
    var fixedFeeKr: Double? = nil

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
    let previousRangeLabel: String
    let comparesSameDays: Bool
}

struct HistoryPriceConsumptionSplit {
    let consumptionEffectKr: Double
    let priceEffectKr: Double
    let previousMonthName: String
    let comparesSameDays: Bool
    /// The part of `priceEffectKr` that comes from the market spot price. Nil when it cannot be told apart.
    var spotEffectKr: Double? = nil
    /// What the spot share is calculated from, so it can be refined with saved intervals.
    var currentKWh: Double = 0
    var vatRate: Double = 0.25
    var isSpotBased = false

    /// Recalculates the spot share from kWh-weighted spot prices (öre/kWh, excluding VAT).
    func refined(currentSpotOre: Double, previousSpotOre: Double) -> HistoryPriceConsumptionSplit {
        guard isSpotBased, currentKWh > 0 else { return self }
        var copy = self
        copy.spotEffectKr = currentKWh * (currentSpotOre - previousSpotOre) / 100 * (1 + vatRate)
        return copy
    }

    /// The rest of the price change: markup, grid transfer and tax per kWh, plus any change in
    /// the fixed monthly fees between the two periods.
    var contractEffectKr: Double? {
        spotEffectKr.map { priceEffectKr - $0 }
    }
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
        // Live numbers from another month (an old cache, say) must never stand in for this month.
        let liveThisMonth = liveMonthlyConsumption.flatMap { live in
            calendar.isDate(live.monthDate, equalTo: summary.periodStart, toGranularity: .month) ? live : nil
        }
        let kWh = isCurrent
            ? (liveThisMonth?.totalKWh ?? summary.totalConsumptionKWh)
            : summary.totalConsumptionKWh
        let spotOre = summary.averageSpotPriceOrePerKWh
        // Past months use the agreement version and fees of their own period.
        let versions = HistoryPricing.savedVersions()
        let periodProfile = isCurrent
            ? costProfile
            : HistoryPricing.periodProfile(at: summary.periodStart, current: costProfile, versions: versions)
        let cost = monthCost(
            summary: summary,
            isCurrentMonth: isCurrent,
            kWh: kWh,
            spotOre: spotOre,
            costProfile: periodProfile,
            livePreciseCost: livePreciseCost,
            now: now,
            calendar: calendar
        )
        let paid = paidKrPerKWh(costKr: cost.amount, kWh: kWh)
        var fixedFee = fixedFeeKr(
            costKr: cost.amount,
            parts: cost.parts,
            profile: periodProfile,
            hours: isCurrent
                ? elapsedHours(from: summary.periodStart, now: now, calendar: calendar)
                : hoursInMonth(containing: summary.periodStart, calendar: calendar),
            measuredShare: summary.measuredCoverageRatio ?? 1
        )
        // A version that starts mid-month: the fixed fees follow each day's version.
        if !isCurrent, cost.parts == nil, let costKr = cost.amount,
           let month = calendar.dateInterval(of: .month, for: summary.periodStart),
           HistoryPricing.hasVersionChange(in: month, versions: versions) {
            let fees = HistoryPricing.fixedFeesKr(in: month, calendar: calendar) { day in
                HistoryPricing.periodProfile(at: day, current: costProfile, versions: versions)
            }
            let share = min(max(summary.measuredCoverageRatio ?? 1, 0), 1)
            fixedFee = min(max(fees * share, 0), max(costKr, 0))
        }

        return HistoryMonthSnapshot(
            summary: summary,
            isCurrentMonth: isCurrent,
            costKr: cost.amount,
            kWh: kWh,
            paidKrPerKWh: paid,
            spotOrePerKWh: spotOre,
            usedCurrentTariffs: cost.usedCurrentTariffs,
            costParts: cost.parts,
            costProfile: periodProfile,
            spotBasisOrePerKWh: cost.spotBasis ?? spotOre,
            fixedFeeKr: fixedFee
        )
    }

    static func comparison(
        current: HistoryMonthSnapshot,
        previous: HistoryMonthSnapshot?,
        previousRangeLabel: String,
        comparesSameDays: Bool
    ) -> HistoryMonthComparison? {
        guard let previous,
              let currentCost = current.costKr,
              let previousCost = previous.costKr,
              isCredibleComparison(currentCost: currentCost, previousCost: previousCost) else {
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
            percentChange: percent,
            previousRangeLabel: previousRangeLabel,
            comparesSameDays: comparesSameDays
        )
    }

    static func priceConsumptionSplit(
        current: HistoryMonthSnapshot,
        previous: HistoryMonthSnapshot?,
        previousRangeLabel: String,
        comparesSameDays: Bool
    ) -> HistoryPriceConsumptionSplit? {
        guard let previous,
              let currentKWh = current.kWh, currentKWh > 0,
              let previousKWh = previous.kWh, previousKWh > 0,
              let currentCost = current.costKr,
              let previousCost = previous.costKr,
              isCredibleComparison(currentCost: currentCost, previousCost: previousCost) else {
            return nil
        }

        // The three effects add up to the cost change exactly. Fixed monthly fees cost the same
        // however much electricity is used, so they are taken out before the per kWh price is
        // worked out. Otherwise a month with more use would look cheaper per kWh just because
        // the same fixed fees were shared over more kWh.
        //   variable cost  = cost - fixed fees           (what depends on the kWh)
        //   consumption    = (kWh now - kWh before) * variable price per kWh before
        //   price          = kWh now * (variable price per kWh now - before) + change in fixed fees
        // Fixed fees only land in the price part when they differ between the two periods,
        // for example across New Year, or when one period has more days than the other.
        // If a fixed share is unknown for either period, both are treated as 0.
        var currentFixed = 0.0
        var previousFixed = 0.0
        if let currentShare = current.fixedFeeKr, let previousShare = previous.fixedFeeKr {
            currentFixed = min(max(currentShare, 0), currentCost)
            previousFixed = min(max(previousShare, 0), previousCost)
        }
        let currentVariablePerKWh = (currentCost - currentFixed) / currentKWh
        let previousVariablePerKWh = (previousCost - previousFixed) / previousKWh

        let consumptionEffectKr = (currentKWh - previousKWh) * previousVariablePerKWh
        let priceEffectKr = currentKWh * (currentVariablePerKWh - previousVariablePerKWh)
            + (currentFixed - previousFixed)
        let reconstructed = consumptionEffectKr + priceEffectKr
        let delta = currentCost - previousCost
        guard abs(reconstructed - delta) <= max(5, abs(delta) * 0.2) else {
            return nil
        }

        // Spot price share of the price change, with VAT, on this month's kWh.
        // Only when both periods price the electricity from the spot price.
        var spotEffectKr: Double?
        if let profile = current.costProfile,
           profile.retailContractType == .spotPriceMarkup,
           let currentSpot = current.spotBasisOrePerKWh,
           let previousSpot = previous.spotBasisOrePerKWh {
            spotEffectKr = currentKWh * (currentSpot - previousSpot) / 100 * (1 + profile.vatRate)
        }

        return HistoryPriceConsumptionSplit(
            consumptionEffectKr: consumptionEffectKr,
            priceEffectKr: priceEffectKr,
            previousMonthName: previousRangeLabel,
            comparesSameDays: comparesSameDays,
            spotEffectKr: spotEffectKr,
            currentKWh: currentKWh,
            vatRate: current.costProfile?.vatRate ?? 0.25,
            isSpotBased: current.costProfile?.retailContractType == .spotPriceMarkup
        )
    }

    static func alignedSnapshot(
        base: HistoryMonthSnapshot,
        dailySummaries: [HistoricalEnergySummaryValue],
        liveConsumption: ConsumptionData?,
        throughDay: Int,
        costProfile: CostProfile,
        now: Date,
        calendar: Calendar
    ) -> HistoryMonthSnapshot? {
        let monthStart = base.summary.periodStart
        let days = dailySummaries.filter { summary in
            calendar.isDate(summary.periodStart, equalTo: monthStart, toGranularity: .month)
                && SameDayMonthComparison.date(summary.periodStart, isOnOrBeforeDay: throughDay, calendar: calendar)
        }
        let liveKWh = liveConsumption.map { consumption in
            consumption.values
                .filter {
                    calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month)
                        && SameDayMonthComparison.date($0.date, isOnOrBeforeDay: throughDay, calendar: calendar)
                }
                .reduce(0) { $0 + $1.kWh }
        }
        let summaryKWh = days.compactMap(\.totalConsumptionKWh).reduce(0, +)
        let measuredDays = days.filter { ($0.totalConsumptionKWh ?? 0) > 0 }
        // Same-day windows must use daily history when it exists. Live `values` can
        // contain other months (day-of-month only is not enough).
        let cappedLive: Double? = {
            guard let liveKWh, liveKWh > 0 else { return nil }
            if let monthTotal = base.kWh, monthTotal > 0, liveKWh > monthTotal * 1.25 {
                return nil
            }
            return liveKWh
        }()
        let usedLiveKWh = summaryKWh <= 0 && (cappedLive ?? 0) > 0
        let kWh = summaryKWh > 0 ? summaryKWh : (cappedLive ?? 0)
        guard kWh > 0 else { return nil }
        if !usedLiveKWh {
            guard measuredDays.count >= max(2, (throughDay + 1) / 2) else { return nil }
        }

        let storedCost = measuredDays.compactMap(\.totalCostSEK)
        let spotParts = days.compactMap { day -> (Double, Double)? in
            guard let dayKWh = day.totalConsumptionKWh, dayKWh > 0,
                  let spot = day.averageSpotPriceOrePerKWh else {
                return nil
            }
            return (dayKWh, spot)
        }
        let spotOre: Double?
        if !spotParts.isEmpty {
            let total = spotParts.reduce(0.0) { $0 + $1.0 }
            spotOre = spotParts.reduce(0.0) { $0 + ($1.0 * $1.1) } / total
        } else {
            spotOre = base.spotOrePerKWh
        }

        let hours: Double
        if let lastInWindow = calendar.date(byAdding: .day, value: throughDay - 1, to: monthStart),
           calendar.isDate(lastInWindow, inSameDayAs: now) {
            hours = elapsedHours(from: monthStart, now: now, calendar: calendar)
        } else {
            hours = Double(throughDay) * 24
        }

        let cost: Double?
        let usedCurrentTariffs: Bool
        var parts: EnhancedCost?
        var fixedFee: Double?
        let windowProfile = base.isCurrentMonth
            ? costProfile
            : HistoryPricing.periodProfile(at: monthStart, current: costProfile)
        if !usedLiveKWh, storedCost.count == measuredDays.count, !storedCost.isEmpty {
            cost = storedCost.reduce(0, +)
            usedCurrentTariffs = false
            // Saved costs carry the fixed fees for the measured days only.
            let measuredHours = measuredDays.reduce(0.0) { $0 + 24 * ($1.measuredCoverageRatio ?? 1) }
            fixedFee = fixedFeeKr(
                costKr: cost,
                parts: nil,
                profile: base.costProfile ?? windowProfile,
                hours: measuredHours,
                measuredShare: 1
            )
        } else if let spotOre {
            let calculated = TotalCostService.shared.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spotOre,
                profile: windowProfile,
                hoursInPeriod: hours
            )
            parts = calculated
            cost = calculated.totalKr
            usedCurrentTariffs = true
            fixedFee = fixedFeeKr(
                costKr: cost,
                parts: calculated,
                profile: windowProfile,
                hours: hours,
                measuredShare: 1
            )
        } else {
            cost = storedCost.isEmpty ? nil : storedCost.reduce(0, +)
            usedCurrentTariffs = false
        }

        return HistoryMonthSnapshot(
            summary: base.summary,
            isCurrentMonth: base.isCurrentMonth,
            costKr: cost,
            kWh: kWh,
            paidKrPerKWh: paidKrPerKWh(costKr: cost, kWh: kWh),
            spotOrePerKWh: spotOre,
            usedCurrentTariffs: usedCurrentTariffs,
            costParts: parts,
            costProfile: base.costProfile ?? costProfile,
            spotBasisOrePerKWh: spotOre,
            fixedFeeKr: fixedFee
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

    static func spotEffectLabel(_ value: Double) -> String {
        if abs(value) < negligibleKr { return "Spotpris" }
        return value > 0 ? "Högre spotpris" : "Lägre spotpris"
    }

    static let contractEffectLabel = "Påslag, elnät och skatt"

    /// "billigare" or "dyrare", so the meaning does not rest on green and red alone.
    /// Nil when the amount is too small to matter.
    static func effectDirectionWord(_ value: Double) -> String? {
        if value > negligibleKr { return "dyrare" }
        if value < -negligibleKr { return "billigare" }
        return nil
    }

    /// For example "-120 kr billigare" or "+45 kr dyrare".
    static func effectAmountText(_ value: Double) -> String {
        let amount = signedKr(value)
        guard let word = effectDirectionWord(value) else { return amount }
        return "\(amount) \(word)"
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
            return "Historiken fylls på när appen har hämtat priser. Förbrukningen har inte kommit in än, men sen ser du vad månaden kostat."
        }
        return "Historiken fylls på när appen har hämtat priser. Lägg till förbrukning i Inställningar, så ser du vad månaden kostar."
    }

    static func missingConsumptionMessage(hasProvider: Bool) -> String {
        if hasProvider {
            return "Månadens förbrukning har inte kommit in än. Så fort den finns ser du vad den kostat."
        }
        return "Lägg till förbrukning i Inställningar, så ser du vad månaden kostar."
    }

    /// Same-day window cost must be in the same ballpark as the number on screen.
    static func alignedCostMatchesDisplayed(
        aligned: HistoryMonthSnapshot,
        displayed: HistoryMonthSnapshot
    ) -> Bool {
        guard let alignedCost = aligned.costKr, let displayedCost = displayed.costKr else {
            return false
        }
        let slack = max(25, abs(displayedCost) * 0.35)
        return abs(alignedCost - displayedCost) <= slack
    }

    /// Drops comparisons where the previous window is empty/near-zero or the
    /// two totals cannot be the same kind of number (öre vs kr, all months, …).
    private static func isCredibleComparison(currentCost: Double, previousCost: Double) -> Bool {
        guard previousCost >= 10, currentCost >= 0 else { return false }
        let ratio = currentCost / previousCost
        return ratio >= 0.12 && ratio <= 8
    }

    private struct MonthCostResult {
        var amount: Double?
        var usedCurrentTariffs: Bool
        var parts: EnhancedCost? = nil
        var spotBasis: Double? = nil
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
    ) -> MonthCostResult {
        let service = TotalCostService.shared

        if isCurrentMonth {
            if let livePreciseCost, livePreciseCost.totalKWh > 0 {
                let effectiveSpot = (livePreciseCost.totalCostKr / livePreciseCost.totalKWh) * 100
                let parts = service.calculateTotalCost(
                    kWh: livePreciseCost.totalKWh,
                    spotPriceOre: effectiveSpot,
                    profile: costProfile,
                    hoursInPeriod: elapsedHours(from: summary.periodStart, now: now, calendar: calendar)
                )
                return MonthCostResult(amount: parts.totalKr, usedCurrentTariffs: true, parts: parts, spotBasis: effectiveSpot)
            }
            if let kWh, kWh > 0, let spotOre {
                let parts = service.calculateTotalCost(
                    kWh: kWh,
                    spotPriceOre: spotOre,
                    profile: costProfile,
                    hoursInPeriod: elapsedHours(from: summary.periodStart, now: now, calendar: calendar)
                )
                return MonthCostResult(amount: parts.totalKr, usedCurrentTariffs: true, parts: parts, spotBasis: spotOre)
            }
            return MonthCostResult(amount: summary.totalCostSEK, usedCurrentTariffs: false)
        }

        if let stored = summary.totalCostSEK {
            return MonthCostResult(amount: stored, usedCurrentTariffs: false)
        }
        if let kWh, kWh > 0, let spotOre {
            let parts = service.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spotOre,
                profile: costProfile,
                hoursInPeriod: hoursInMonth(containing: summary.periodStart, calendar: calendar)
            )
            return MonthCostResult(amount: parts.totalKr, usedCurrentTariffs: true, parts: parts, spotBasis: spotOre)
        }
        return MonthCostResult(amount: nil, usedCurrentTariffs: false)
    }

    private static func hoursInMonth(containing date: Date, calendar: Calendar) -> Double {
        let days = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        return Double(days * 24)
    }

    private static func elapsedHours(from monthStart: Date, now: Date, calendar: Calendar) -> Double {
        let start = calendar.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
        return max(now.timeIntervalSince(start) / 3600, 1 / 60)
    }

    /// The fixed monthly fees inside a cost, with VAT. From the cost parts when they exist,
    /// otherwise from the profile's monthly fees, spread over the hours the cost covers
    /// (730 hours to a month, the same as the cost calculation). Nil when it cannot be told.
    private static func fixedFeeKr(
        costKr: Double?,
        parts: EnhancedCost?,
        profile: CostProfile?,
        hours: Double,
        measuredShare: Double
    ) -> Double? {
        guard let costKr else { return nil }
        let vat = profile?.vatRate ?? 0.25
        let fee: Double
        if let parts {
            fee = (parts.fixedFeeCostKr + parts.powerTariffCostKr + parts.providerMonthlyFeeKr) * (1 + vat)
        } else if let profile {
            let monthly = (profile.gridMonthlyFee ?? 0) + profile.retailerMonthlyFee
            fee = monthly / 730 * hours * min(max(measuredShare, 0), 1)
        } else {
            return nil
        }
        return min(max(fee, 0), max(costKr, 0))
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


// MARK: - Month cost breakdown

struct MonthCostLine: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// Excluding VAT, except the "Moms" line itself.
    let amountKr: Double
    /// Rounded for display. The lines add up to `MonthCostBreakdown.totalWholeKr`.
    var wholeKr: Int = 0
    /// What is inside a folded line.
    var detail: String? = nil
}

/// What one month's cost consists of, in kronor. The lines add up to the
/// number on the card exactly, rounded the same way.
struct MonthCostBreakdown: Equatable, Sendable {
    let lines: [MonthCostLine]
    let totalKr: Double
    let totalWholeKr: Int
    let kWh: Double?
    /// Shown under the lines, for example when the grid fee is not included.
    var note: String? = nil

    var krPerKWh: Double? {
        guard let kWh, kWh > 0 else { return nil }
        return totalKr / kWh
    }

    /// Full split, from the same cost calculation as the total.
    static func make(parts cost: EnhancedCost, profile: CostProfile, kWh: Double?) -> MonthCostBreakdown {
        var raw: [MonthCostLine] = []
        func add(_ id: String, _ title: String, _ amount: Double) {
            guard amount > 0.0000001 else { return }
            raw.append(MonthCostLine(id: id, title: title, amountKr: amount))
        }
        let spotTitle = profile.retailContractType == .spotPriceMarkup ? "Spotpris" : profile.retailContractDisplayName
        add("spot", spotTitle, cost.spotCostKr)
        if profile.retailContractType == .spotPriceMarkup {
            add("markup", "Elhandlarens påslag", cost.providerSurchargeKr)
        }
        add("retailFee", "Elhandlarens månadsavgift", cost.providerMonthlyFeeKr)
        if profile.hasConfiguredGridCosts {
            add("grid", "Elnätsavgift", cost.gridEnergyCostKr)
        }
        add("gridFee", "Elnätets månadsavgift", cost.fixedFeeCostKr)
        add("power", EffectTariffCopy.lineTitle, cost.powerTariffCostKr)
        add("tax", "Skatt på el", cost.energyTaxKr)
        add("cert", "Elcertifikat", cost.certificateFeeKr)

        // Lines under 2 % of the total go into one "Annat smått" line, as in the kr/kWh view.
        let total = cost.totalKr
        let keepIds: Set<String> = ["spot", "markup"]
        let small = raw.filter { !keepIds.contains($0.id) && total > 0 && $0.amountKr / total < 0.02 }
        if small.count > 1 {
            let folded = MonthCostLine(
                id: "other",
                title: "Annat smått",
                amountKr: small.reduce(0) { $0 + $1.amountKr },
                detail: small.map(\.title).joined(separator: ", ")
            )
            raw = raw.filter { line in !small.contains { $0.id == line.id } }
            raw.append(folded)
        }
        add("vat", "Moms", cost.vatKr)

        return finish(
            raw,
            totalKr: total,
            kWh: kWh,
            note: profile.hasConfiguredGridCosts ? nil : "Elnätsavgift ingår inte. Välj elnätsbolag under Inställningar."
        )
    }

    /// Coarser split for saved months, from the saved intervals. Returns nil unless the
    /// intervals add up to the total on the card.
    static func make(
        intervals: [HistoricalEnergyIntervalValue],
        retailContractType: RetailContractType,
        displayedTotalKr: Double
    ) -> MonthCostBreakdown? {
        var kWh = 0.0, spot = 0.0, energy = 0.0, grid = 0.0, tax = 0.0, vat = 0.0, total = 0.0
        for interval in intervals {
            guard let used = interval.consumptionKWh, used > 0,
                  let intervalTotal = interval.totalCostSEK else { continue }
            kWh += used
            spot += used * interval.spotPriceOrePerKWh / 100
            energy += interval.energyCostSEK ?? 0
            grid += interval.gridCostSEK ?? 0
            tax += interval.taxCostSEK ?? 0
            vat += interval.vatCostSEK ?? 0
            total += intervalTotal
        }
        guard kWh > 0, abs(total - displayedTotalKr) <= 1.5 else { return nil }

        var raw: [MonthCostLine] = []
        func add(_ id: String, _ title: String, _ amount: Double) {
            guard amount > 0.0000001 else { return }
            raw.append(MonthCostLine(id: id, title: title, amountKr: amount))
        }
        if retailContractType == .spotPriceMarkup {
            let rest = energy - spot
            guard rest > -0.5 else { return nil }
            add("spot", "Spotpris", spot)
            add("markup", "Elhandlarens påslag och avgifter", max(rest, 0))
        } else {
            add("spot", "Elhandel", energy)
        }
        add("grid", "Elnät, överföring och fasta avgifter", grid)
        add("tax", "Skatt på el och elcertifikat", tax)
        add("vat", "Moms", vat)
        return finish(raw, totalKr: total, kWh: kWh, note: nil)
    }

    /// Rounds to whole kronor so the shown lines add up to the shown total.
    private static func finish(_ lines: [MonthCostLine], totalKr: Double, kWh: Double?, note: String?) -> MonthCostBreakdown {
        let totalWhole = Int(totalKr.rounded())
        var rounded = lines
        let floors = lines.map { Int($0.amountKr.rounded(.down)) }
        for index in rounded.indices { rounded[index].wholeKr = floors[index] }
        var missing = totalWhole - floors.reduce(0, +)
        let order = lines.indices.sorted {
            (lines[$0].amountKr - Double(floors[$0])) > (lines[$1].amountKr - Double(floors[$1]))
        }
        var cursor = 0
        while missing > 0, !order.isEmpty {
            rounded[order[cursor % order.count]].wholeKr += 1
            missing -= 1
            cursor += 1
        }
        while missing < 0, !order.isEmpty {
            let index = order[order.count - 1 - (cursor % order.count)]
            if rounded[index].wholeKr > 0 { rounded[index].wholeKr -= 1; missing += 1 }
            cursor += 1
            if cursor > order.count * 4 { break }
        }
        return MonthCostBreakdown(lines: rounded, totalKr: totalKr, totalWholeKr: totalWhole, kWh: kWh, note: note)
    }
}

// MARK: - Temperature-adjusted consumption

nonisolated struct TemperatureUsagePeriod: Equatable, Sendable {
    var name: String
    var kWh: Double
    var meanTempC: Double
    var heatingDegreeDays: Double
    var dayCount: Int
    /// Days in the compared window, with or without measurements. 0 when unknown.
    var windowDays: Int = 0
}

/// Which two periods a temperature comparison sets side by side.
/// `partial` means only the days measured so far are compared.
nonisolated enum TemperatureComparisonKind: Equatable, Sendable {
    case previousMonth(partial: Bool)
    case yearAgo(partial: Bool)
}

nonisolated struct TemperatureInsight: Equatable, Sendable, Identifiable {
    var id: String
    /// Short text for the card.
    var title: String
    /// Longer explanation for the info sheet.
    var details: [String]
    var isUncertain: Bool
}

nonisolated enum TemperatureAdjustment {
    static let baseTemperatureC = 17.0
    private static let minimumDays = 14
    private static let minimumCorrelation = 0.35
    private static let confidentCorrelation = 0.55
    private static let minimumSlope = 0.05
    private static let similarUsePercent = 5.0
    private static let similarTempC = 0.8

    static func heatingDegreeDays(meanTempC: Double) -> Double {
        max(0, baseTemperatureC - meanTempC)
    }

    static func period(
        name: String,
        days: [Date],
        kWhByDay: [Date: Double],
        temperatures: [Date: Double],
        calendar: Calendar
    ) -> TemperatureUsagePeriod? {
        var usedKWh = 0.0
        var usedHDD = 0.0
        var usedTemp = 0.0
        var count = 0
        for day in days {
            let key = calendar.startOfDay(for: day)
            guard let kWh = kWhByDay[key], kWh > 0, let temp = temperatures[key] else { continue }
            usedKWh += kWh
            usedHDD += heatingDegreeDays(meanTempC: temp)
            usedTemp += temp
            count += 1
        }
        let coverage = days.isEmpty ? 0 : Double(count) / Double(days.count)
        guard count >= 3, usedKWh > 0, coverage >= 0.7 else { return nil }
        return TemperatureUsagePeriod(
            name: name,
            kWh: usedKWh,
            meanTempC: usedTemp / Double(count),
            heatingDegreeDays: usedHDD,
            dayCount: count,
            windowDays: days.count
        )
    }

    static func fit(
        kWhByDay: [Date: Double],
        temperatures: [Date: Double],
        baseloadKW: Double?,
        calendar: Calendar
    ) -> (baseKWhPerDay: Double, slope: Double, correlation: Double, samples: Int)? {
        var points: [(hdd: Double, kWh: Double)] = []
        let keys = Set(kWhByDay.keys).intersection(temperatures.keys)
        for key in keys {
            guard let kWh = kWhByDay[key], kWh > 0, let temp = temperatures[key] else { continue }
            points.append((heatingDegreeDays(meanTempC: temp), kWh))
        }
        guard points.count >= minimumDays else { return nil }

        let summer = points.filter { $0.hdd < 1 }
        let priorBase: Double?
        if summer.count >= 5 {
            priorBase = median(summer.map(\.kWh))
        } else if let baseloadKW, baseloadKW > 0 {
            priorBase = baseloadKW * 24
        } else {
            priorBase = nil
        }

        let hdd = points.map(\.hdd)
        let kWh = points.map(\.kWh)
        let correlation = pearson(hdd, kWh) ?? 0
        let varianceX = variance(hdd)
        guard varianceX > 0.05 else { return nil }

        let slope: Double
        let base: Double
        if let priorBase {
            let residual = zip(kWh, hdd).map { energy, _ in energy - priorBase }
            let sumX2 = hdd.reduce(0.0) { $0 + $1 * $1 }
            let num = zip(hdd, residual).reduce(0.0) { sum, pair in sum + pair.0 * pair.1 }
            slope = sumX2 > 0 ? num / sumX2 : 0
            base = max(priorBase, 0)
        } else {
            let meanX = hdd.reduce(0, +) / Double(hdd.count)
            let meanY = kWh.reduce(0, +) / Double(kWh.count)
            let num = zip(hdd, kWh).reduce(0.0) { sum, pair in sum + (pair.0 - meanX) * (pair.1 - meanY) }
            slope = num / (varianceX * Double(hdd.count))
            base = max(meanY - slope * meanX, 0)
        }
        guard slope >= minimumSlope, correlation >= minimumCorrelation else { return nil }
        return (base, slope, correlation, points.count)
    }

    static func insight(
        current: TemperatureUsagePeriod,
        reference: TemperatureUsagePeriod,
        fit: (baseKWhPerDay: Double, slope: Double, correlation: Double, samples: Int)?,
        id: String,
        kind: TemperatureComparisonKind
    ) -> TemperatureInsight? {
        guard current.dayCount >= 3, reference.dayCount >= 3, reference.kWh > 0 else { return nil }
        let rawPercent = (current.kWh - reference.kWh) / reference.kWh * 100
        let colder = current.meanTempC <= reference.meanTempC - similarTempC
        let warmer = current.meanTempC >= reference.meanTempC + similarTempC
        let weatherDiffers = colder || warmer

        // Why the weather adjustment is missing or rougher than usual. These go
        // behind the info button, never on the card.
        var notes: [String] = []
        let adjusted: Double?
        let uncertain: Bool
        if let fit {
            let base = min(fit.baseKWhPerDay * Double(current.dayCount), current.kWh)
            let heat = max(0, current.kWh - base)
            if current.heatingDegreeDays < 0.5 && reference.heatingDegreeDays < 0.5 {
                adjusted = current.kWh
                uncertain = fit.correlation < confidentCorrelation
                if uncertain {
                    notes.append("Din förbrukning följer vädret bara svagt.")
                }
            } else if current.heatingDegreeDays < 0.5 || heat < current.kWh * 0.08 {
                // Use is at or below the estimated always-on part, so a weather
                // scale would invent a different total. Keep the raw number.
                adjusted = nil
                uncertain = true
                notes.append("Nästan all el gick åt till annat än värme, så en omräkning för vädret skulle bli missvisande.")
            } else {
                adjusted = base + heat * (reference.heatingDegreeDays / current.heatingDegreeDays)
                uncertain = fit.correlation < confidentCorrelation || fit.samples < 21
                if fit.correlation < confidentCorrelation {
                    notes.append("Din förbrukning följer vädret bara svagt.")
                }
                if fit.samples < 21 {
                    notes.append("Vi har färre än tre veckors dagar med mätvärden att räkna på.")
                }
            }
        } else {
            adjusted = nil
            uncertain = true
            notes.append("Vi har för få dagar med både mätvärden och temperatur, eller så följer din förbrukning inte vädret tydligt nog.")
        }

        let subject = subjectText(current.name, kind: kind)
        let temps = temperaturePair(current.meanTempC, reference.meanTempC)
        let comparedTo = titleReference(reference.name, kind: kind)

        // Card text: one sentence about the weather, one about the use.
        let weatherSentence: String
        if colder {
            weatherSentence = "\(subject) var kallare än \(comparedTo) (\(temps))."
        } else if warmer {
            weatherSentence = "\(subject) var varmare än \(comparedTo) (\(temps))."
        } else {
            weatherSentence = "\(subject) var ungefär lika varm som \(comparedTo) (\(temps))."
        }

        let rawPhrase = usePhrase(rawPercent)
        let rawConnector = abs(rawPercent) < similarUsePercent ? "som" : "än"
        let rawSentence = "Du använde \(rawPhrase) \(rawConnector) \(comparedTo)."
        let usageSentence: String
        let approx = adjusted.map { approximateUse((($0 - reference.kWh) / reference.kWh) * 100) }
        if weatherDiffers, let approx {
            usageSentence = "Räknat på samma väder använde du \(approx.phrase)."
        } else if weatherDiffers {
            usageSentence = "\(rawSentence) Det går inte att räkna om till samma väder."
        } else {
            usageSentence = rawSentence
        }

        // Info sheet text.
        var details: [String] = []
        details.append(
            "\(subject) mot \(detailReference(reference.name, kind: kind)). Utan hänsyn till vädret använde du \(rawPhrase) el. I snitt var det \(temps)."
        )
        if weatherDiffers, adjusted != nil, let approx {
            let heatLine = colder
                ? "Det var kallare, så mer av elen gick till uppvärmning."
                : "Det var varmare, så mindre av elen gick till uppvärmning."
            let connector = approx.usesAs ? "som" : "än"
            details.append(
                "\(heatLine) Räknat på samma väder räknar vi om förbrukningen som om vädret hade varit som \(inReference(reference.name, kind: kind)). Då hade du använt \(approx.phrase) \(connector) \(inReference(reference.name, kind: kind))."
            )
        }
        if weatherDiffers, adjusted == nil {
            details.append("Därför visar kortet bara förbrukningen som den är, utan omräkning för vädret.")
        }
        if uncertain, !notes.isEmpty {
            let lead = adjusted == nil
                ? "Varför det inte går att räkna om."
                : "Därför är uppskattningen extra grov här."
            details.append("\(lead) \(notes.joined(separator: " "))")
        }
        for (period, label) in [(current, "\(current.name)"), (reference, "\(detailReference(reference.name, kind: kind))")]
        where period.windowDays > period.dayCount {
            let missing = period.windowDays - period.dayCount
            let dayWord = missing == 1 ? "dag" : "dagar"
            details.append("Det saknas mätvärden för \(missing) \(dayWord) i \(label). De dagarna är inte med i jämförelsen.")
        }

        return TemperatureInsight(
            id: id,
            title: "\(weatherSentence) \(usageSentence)",
            details: details,
            isUncertain: uncertain
        )
    }

    // MARK: Wording

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// "Oktober", "Oktober hittills", "Oktober i år" or "Oktober hittills i år".
    static func subjectText(_ month: String, kind: TemperatureComparisonKind) -> String {
        let name = capitalized(month)
        switch kind {
        case .previousMonth(let partial):
            return partial ? "\(name) hittills" : name
        case .yearAgo(let partial):
            return partial ? "\(name) hittills i år" : "\(name) i år"
        }
    }

    /// Used after "än" and "som" on the card: "september", "samma dagar i september", "i fjol".
    static func titleReference(_ month: String, kind: TemperatureComparisonKind) -> String {
        switch kind {
        case .previousMonth(let partial):
            return partial ? "samma dagar i \(month)" : month
        case .yearAgo(let partial):
            return partial ? "samma dagar i fjol" : "i fjol"
        }
    }

    /// "i september", "samma dagar i september", "i fjol", "samma dagar i fjol".
    static func inReference(_ month: String, kind: TemperatureComparisonKind) -> String {
        switch kind {
        case .previousMonth(let partial):
            return partial ? "samma dagar i \(month)" : "i \(month)"
        case .yearAgo(let partial):
            return partial ? "samma dagar i fjol" : "i fjol"
        }
    }

    /// "september", "samma dagar i september", "oktober i fjol", "samma dagar i oktober i fjol".
    static func detailReference(_ month: String, kind: TemperatureComparisonKind) -> String {
        switch kind {
        case .previousMonth(let partial):
            return partial ? "samma dagar i \(month)" : month
        case .yearAgo(let partial):
            return partial ? "samma dagar i \(month) i fjol" : "\(month) i fjol"
        }
    }

    /// Rounded wording for an estimate: it never claims more precision than it has.
    static func approximateUse(_ percent: Double) -> (phrase: String, usesAs: Bool) {
        if abs(percent) < similarUsePercent {
            return ("ungefär lika mycket", true)
        }
        if percent >= 85 && percent <= 115 {
            return ("ungefär dubbelt så mycket", true)
        }
        if percent >= -55 && percent <= -45 {
            return ("ungefär hälften så mycket", true)
        }
        var amount = abs(percent).rounded()
        if amount >= 20 {
            amount = (amount / 5).rounded() * 5
        }
        let word = percent > 0 ? "mer" : "mindre"
        return ("ungefär \(Int(amount)) procent \(word)", false)
    }

    static func temperaturePair(_ current: Double, _ reference: Double) -> String {
        let unit = degreeNumber(reference) == "1" ? "grad" : "grader"
        return "\(degreeNumber(current)) mot \(degreeNumber(reference)) \(unit)"
    }

    static func usePhrase(_ percent: Double) -> String {
        let amount = Int(abs(percent).rounded())
        if percent > similarUsePercent {
            return "\(amount) procent mer"
        }
        if percent < -similarUsePercent {
            return "\(amount) procent mindre"
        }
        return "ungefär lika mycket"
    }

    /// "8,5", "12", "minus 2,5". No unit.
    static func degreeNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let isWhole = abs(rounded - rounded.rounded()) < 0.05
        let number: String
        if isWhole {
            number = String(Int(abs(rounded).rounded()))
        } else {
            number = String(format: "%.1f", abs(rounded)).replacingOccurrences(of: ".", with: ",")
        }
        return rounded < 0 ? "minus \(number)" : number
    }

    static func degrees(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let unit = abs(abs(rounded) - 1) < 0.05 ? "grad" : "grader"
        return "\(degreeNumber(value)) \(unit)"
    }

    static func daysInWindow(
        monthStart: Date,
        throughDay: Int?,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: monthStart)
        let lastDay = throughDay ?? (calendar.range(of: .day, in: .month, for: start)?.count ?? 1)
        return (1...lastDay).compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    static func kWhByDay(from summaries: [HistoricalEnergySummaryValue], calendar: Calendar) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.periodStart)
            if let kWh = summary.totalConsumptionKWh, kWh > 0 {
                result[day] = kWh
            }
        }
        return result
    }

    #if DEBUG
    static func debugVerifyKnownExamples() -> Bool {
        // Three mild days and three colder days, 20 kWh base + 1 kWh per degree-day.
        let calendar = Calendar.energyHistory
        let mild = (0..<15).compactMap { offset -> (Date, Double, Double)? in
            guard let day = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1 + offset)) else { return nil }
            return (day, 20.0, 17.0) // HDD 0, kWh 20
        }
        let cold = (0..<15).compactMap { offset -> (Date, Double, Double)? in
            guard let day = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1 + offset)) else { return nil }
            return (day, 30.0, 7.0) // HDD 10, kWh 30
        }
        var kWh: [Date: Double] = [:]
        var temps: [Date: Double] = [:]
        for (day, energy, temp) in mild + cold {
            kWh[day] = energy
            temps[day] = temp
        }
        guard let fit = fit(kWhByDay: kWh, temperatures: temps, baseloadKW: 20.0 / 24.0, calendar: calendar) else {
            return false
        }
        let baseOK = abs(fit.baseKWhPerDay - 20) < 1.5
        let slopeOK = abs(fit.slope - 1) < 0.15
        let corrOK = fit.correlation > 0.95

        let currentDays = cold.map(\.0)
        let referenceDays = (0..<15).compactMap { offset in
            calendar.date(from: DateComponents(year: 2025, month: 10, day: 1 + offset))
        }
        // Reference: 5°C warmer than the cold month, HDD 5, kWh 25
        var refKWh: [Date: Double] = [:]
        var refTemp: [Date: Double] = [:]
        for day in referenceDays {
            refKWh[day] = 25
            refTemp[day] = 12
        }
        let allTemps = temps.merging(refTemp) { _, new in new }
        let allKWh = kWh.merging(refKWh) { _, new in new }
        guard
            let current = period(name: "november", days: currentDays, kWhByDay: allKWh, temperatures: allTemps, calendar: calendar),
            let reference = period(name: "oktober", days: referenceDays, kWhByDay: allKWh, temperatures: allTemps, calendar: calendar)
        else {
            return false
        }
        // Adjust current (450 kWh, HDD 150) to October HDD 75: 20*15 + 150*(75/150) = 300+75 = 375
        // October is 375 kWh, so adjusted use is equal.
        let insight = insight(current: current, reference: reference, fit: fit, id: "test", kind: .previousMonth(partial: false))
        let mentionsEqual = insight?.title.contains("ungefär lika mycket") == true
        let mentionsColder = insight?.title.contains("kallare") == true
        return baseOK && slopeOK && corrOK && mentionsEqual && mentionsColder
    }
    #endif

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func variance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    }

    private static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count > 1 else { return nil }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0
        var denX = 0.0
        var denY = 0.0
        for (x, y) in zip(xs, ys) {
            let dx = x - meanX
            let dy = y - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        let den = (denX * denY).squareRoot()
        guard den > 0 else { return nil }
        return num / den
    }
}
