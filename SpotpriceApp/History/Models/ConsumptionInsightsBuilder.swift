import Foundation

nonisolated enum ConsumptionInsightsBuilder: Sendable {
    private static let nightEndHour = 5
    private static let baseloadPercentile = 0.10
    private static let shortPeakHours = 1.5
    private static let longLoadHours = 3.0
    private static let expensiveSpotPercentile = 0.75

    nonisolated static func make(
        intervals: [HistoricalEnergyIntervalValue],
        previousIntervals: [HistoricalEnergyIntervalValue],
        dailySummaries: [HistoricalEnergySummaryValue],
        costProfile: CostProfile,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        periodKind: ConsumptionInsightsPeriodKind,
        includeHypotheticalEffectTariff: Bool = false,
        includeElectricCarGuess: Bool = false,
        factors: ConsumptionInsightsFactors = .none
    ) -> ConsumptionInsights {
        let calendar = Calendar.energyHistory
        let samples = measuredSamples(from: intervals, costProfile: costProfile)
        let resolution = detectResolution(samples: samples, dailySummaries: dailySummaries)

        guard resolution != .none else {
            return empty(
                periodKind: periodKind,
                periodStart: periodStart,
                periodEnd: periodEnd,
                factors: factors
            )
        }

        let baseload: ConsumptionBaseloadInsight?
        if resolution == .daily {
            baseload = dailyBaseload(
                dailySummaries: dailySummaries,
                previousIntervals: previousIntervals,
                costProfile: costProfile,
                calendar: calendar
            )
        } else {
            let previousSamples = measuredSamples(from: previousIntervals, costProfile: costProfile)
            baseload = intervalBaseload(
                samples: samples,
                previousSamples: previousSamples,
                calendar: calendar
            )
        }

        let events: [ConsumptionLoadEvent]
        let eventsUnavailableReason: String?
        if resolution == .daily {
            events = []
            eventsUnavailableReason = "Toppar kräver tim- eller kvartsvärden."
        } else if let baseload {
            events = loadEvents(from: samples, baseloadKW: baseload.powerKW)
            eventsUnavailableReason = events.isEmpty ? "Inga tydliga toppar över det du alltid drar." : nil
        } else {
            events = []
            eventsUnavailableReason = "Det du alltid drar saknas, så topparna kan inte räknas ut."
        }

        let diurnal: ConsumptionDiurnalInsight?
        let diurnalUnavailableReason: String?
        if resolution == .daily {
            diurnal = nil
            diurnalUnavailableReason = "Dygnsprofilen kräver tim- eller kvartsvärden."
        } else {
            diurnal = diurnalProfile(from: samples, baseloadKW: baseload?.powerKW ?? 0, periodKind: periodKind, calendar: calendar)
            diurnalUnavailableReason = diurnal == nil ? "För få timmar med förbrukning för en dygnsprofil." : nil
        }

        let powerPeak: ConsumptionPowerPeakInsight?
        let powerPeakUnavailableReason: String?
        if resolution == .daily {
            powerPeak = nil
            powerPeakUnavailableReason = "Timtoppen saknas när bara dygnsvärden finns."
        } else {
            powerPeak = hourPeak(
                from: samples,
                costProfile: costProfile,
                includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
                calendar: calendar
            )
            powerPeakUnavailableReason = powerPeak == nil ? "Ingen timme med förbrukning att mäta topp på." : nil
        }

        let evCharging: ConsumptionEVChargingInsight?
        if includeElectricCarGuess, let baseload, resolution != .daily {
            evCharging = electricCarGuess(from: samples, baseloadKW: baseload.powerKW, calendar: calendar)
        } else {
            evCharging = nil
        }

        let summarySentences = summary(
            periodKind: periodKind,
            resolution: resolution,
            baseload: baseload,
            events: events,
            diurnal: diurnal,
            powerPeak: powerPeak,
            samples: samples
        )

        return ConsumptionInsights(
            periodKind: periodKind,
            periodStart: periodStart,
            periodEnd: min(periodEnd, now),
            resolution: resolution,
            factors: factors,
            summarySentences: summarySentences,
            baseload: baseload,
            events: events,
            eventsUnavailableReason: eventsUnavailableReason,
            diurnal: diurnal,
            diurnalUnavailableReason: diurnalUnavailableReason,
            powerPeak: powerPeak,
            powerPeakUnavailableReason: powerPeakUnavailableReason,
            evCharging: evCharging
        )
    }

    // MARK: - Resolution

    nonisolated private static func detectResolution(
        samples: [Sample],
        dailySummaries: [HistoricalEnergySummaryValue]
    ) -> ConsumptionInsightsResolution {
        let durations = samples.map(\.hours).sorted()
        if let median = percentile(durations, 0.50) {
            if median <= 0.4 {
                return .quarterHour
            }
            if median <= 1.6 {
                return .hourly
            }
        }
        if dailySummaries.contains(where: { ($0.totalConsumptionKWh ?? 0) > 0 }) {
            return .daily
        }
        if !samples.isEmpty {
            return .hourly
        }
        return .none
    }

    // MARK: - Samples

    nonisolated private struct Sample: Sendable {
        let start: Date
        let end: Date
        let hours: Double
        let kWh: Double
        let kW: Double
        let costKr: Double
        let spotOre: Double
    }

    nonisolated private static func measuredSamples(
        from intervals: [HistoricalEnergyIntervalValue],
        costProfile: CostProfile
    ) -> [Sample] {
        let service = TotalCostService.shared
        return intervals.compactMap { interval in
            guard let kWh = interval.consumptionKWh, kWh >= 0 else { return nil }
            let hours = interval.intervalEnd.timeIntervalSince(interval.intervalStart) / 3600
            guard hours > 0.001 else { return nil }
            let cost: Double
            if let stored = interval.totalCostSEK {
                cost = stored
            } else if kWh > 0 {
                cost = service.calculateTotalCost(
                    kWh: kWh,
                    spotPriceOre: interval.spotPriceOrePerKWh,
                    profile: costProfile,
                    hoursInPeriod: hours
                ).totalKr
            } else {
                cost = 0
            }
            return Sample(
                start: interval.intervalStart,
                end: interval.intervalEnd,
                hours: hours,
                kWh: kWh,
                kW: kWh / hours,
                costKr: cost,
                spotOre: interval.spotPriceOrePerKWh
            )
        }
        .sorted { $0.start < $1.start }
    }

    // MARK: - Baseload

    nonisolated private static func intervalBaseload(
        samples: [Sample],
        previousSamples: [Sample],
        calendar: Calendar
    ) -> ConsumptionBaseloadInsight? {
        guard let powerKW = nightBaseloadKW(from: samples, calendar: calendar) else {
            return nil
        }
        let elapsedHours = samples.reduce(0.0) { $0 + $1.hours }
        let energyKWh = powerKW * elapsedHours
        let costKr = samples.reduce(0.0) { sum, sample in
            guard sample.kWh > 0 else { return sum }
            let baseKWh = min(sample.kWh, powerKW * sample.hours)
            return sum + sample.costKr * (baseKWh / sample.kWh)
        }
        let previousPowerKW = nightBaseloadKW(from: previousSamples, calendar: calendar)
        let previousMonthName = SameDayMonthComparison.previousPeriodLabel(
            from: previousSamples.map(\.start),
            calendar: calendar
        )
        return ConsumptionBaseloadInsight(
            powerKW: powerKW,
            energyKWh: energyKWh,
            costKr: costKr,
            previousPowerKW: previousPowerKW,
            previousMonthName: previousMonthName,
            usedNightPercentile: true
        )
    }

    nonisolated private static func nightBaseloadKW(from samples: [Sample], calendar: Calendar) -> Double? {
        let night = samples.filter { calendar.component(.hour, from: $0.start) < nightEndHour }
        let grouped = Dictionary(grouping: night) { calendar.startOfDay(for: $0.start) }
        var daily: [Double] = []
        daily.reserveCapacity(grouped.count)
        for (_, daySamples) in grouped {
            let powers = daySamples.map(\.kW)
            guard powers.count >= 2, let value = percentile(powers, baseloadPercentile) else {
                continue
            }
            daily.append(value)
        }
        if let median = percentile(daily.sorted(), 0.50) {
            return median
        }
        return percentile(night.map(\.kW), baseloadPercentile)
    }

    nonisolated private static func dailyBaseload(
        dailySummaries: [HistoricalEnergySummaryValue],
        previousIntervals: [HistoricalEnergyIntervalValue],
        costProfile: CostProfile,
        calendar: Calendar
    ) -> ConsumptionBaseloadInsight? {
        let days = dailySummaries.compactMap { summary -> (kWh: Double, cost: Double, hours: Double)? in
            guard let kWh = summary.totalConsumptionKWh, kWh > 0 else { return nil }
            return (kWh, summary.totalCostSEK ?? 0, 24)
        }
        guard let minKWh = days.map(\.kWh).min() else { return nil }
        let powerKW = minKWh / 24
        let energyKWh = powerKW * Double(days.count) * 24
        let costKr = days.reduce(0.0) { sum, day in
            guard day.kWh > 0 else { return sum }
            return sum + day.cost * ((powerKW * day.hours) / day.kWh)
        }
        let previousPowerKW = nightBaseloadKW(
            from: measuredSamples(from: previousIntervals, costProfile: costProfile),
            calendar: calendar
        )
        return ConsumptionBaseloadInsight(
            powerKW: powerKW,
            energyKWh: energyKWh,
            costKr: costKr,
            previousPowerKW: previousPowerKW,
            previousMonthName: SameDayMonthComparison.previousPeriodLabel(
                from: previousIntervals.map(\.intervalStart),
                calendar: calendar
            ),
            usedNightPercentile: false
        )
    }

    // MARK: - Events

    nonisolated private static func loadEvents(
        from samples: [Sample],
        baseloadKW: Double
    ) -> [ConsumptionLoadEvent] {
        let threshold = max(baseloadKW * 1.55, baseloadKW + 0.35, 0.45)
        let hold = max(baseloadKW * 1.25, baseloadKW + 0.18, 0.30)
        var current: [Sample] = []
        var found: [ConsumptionLoadEvent] = []

        func closeEvent() {
            guard let first = current.first, let last = current.last else {
                current.removeAll(keepingCapacity: true)
                return
            }
            let durationHours = last.end.timeIntervalSince(first.start) / 3600
            guard durationHours >= 0.2 else {
                current.removeAll(keepingCapacity: true)
                return
            }
            let energyKWh = current.reduce(0.0) { $0 + $1.kWh }
            let extraEnergyKWh = current.reduce(0.0) { $0 + max(0, $1.kWh - baseloadKW * $1.hours) }
            let costKr = current.reduce(0.0) { sum, sample in
                guard sample.kWh > 0 else { return sum }
                let extra = max(0, sample.kWh - baseloadKW * sample.hours)
                return sum + sample.costKr * (extra / sample.kWh)
            }
            let peakKW = current.map(\.kW).max() ?? 0
            let shape = classifyEvent(durationHours: durationHours, peakKW: peakKW, baseloadKW: baseloadKW)
            found.append(
                ConsumptionLoadEvent(
                    start: first.start,
                    end: last.end,
                    energyKWh: energyKWh,
                    extraEnergyKWh: extraEnergyKWh,
                    peakKW: peakKW,
                    costKr: costKr,
                    shape: shape
                )
            )
            current.removeAll(keepingCapacity: true)
        }

        for sample in samples {
            let inEvent = !current.isEmpty
            let limit = inEvent ? hold : threshold
            let gap = current.last.map { sample.start.timeIntervalSince($0.end) > 20 * 60 } ?? false
            if sample.kW >= limit && !gap {
                current.append(sample)
            } else {
                closeEvent()
                if sample.kW >= threshold {
                    current = [sample]
                }
            }
        }
        closeEvent()

        return Array(
            found
                .sorted { $0.costKr > $1.costKr }
                .prefix(5)
        )
    }

    nonisolated private static func classifyEvent(
        durationHours: Double,
        peakKW: Double,
        baseloadKW: Double
    ) -> ConsumptionLoadEventShape {
        let clearlyAboveBaseload = peakKW >= max(baseloadKW * 2.5, 1.5)
        if durationHours <= shortPeakHours + 0.05 && clearlyAboveBaseload {
            return .shortHighPeak
        }
        if durationHours >= longLoadHours - 0.05 {
            return .longEvenLoad
        }
        return .other
    }

    // MARK: - Diurnal

    nonisolated private static func diurnalProfile(
        from samples: [Sample],
        baseloadKW: Double,
        periodKind: ConsumptionInsightsPeriodKind,
        calendar: Calendar
    ) -> ConsumptionDiurnalInsight? {
        guard !samples.isEmpty else { return nil }

        var kWhByDayHour: [Date: [Int: Double]] = [:]
        var costByDayHour: [Date: [Int: Double]] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.start)
            let hour = calendar.component(.hour, from: sample.start)
            kWhByDayHour[day, default: [:]][hour, default: 0] += sample.kWh
            costByDayHour[day, default: [:]][hour, default: 0] += sample.costKr
        }

        var bars: [ConsumptionHourProfileBar] = []
        bars.reserveCapacity(24)
        for hour in 0..<24 {
            let kWhs = kWhByDayHour.values.compactMap { $0[hour] }
            let costs = costByDayHour.values.compactMap { $0[hour] }
            let averageKWh = kWhs.isEmpty ? 0 : kWhs.reduce(0, +) / Double(kWhs.count)
            bars.append(
                ConsumptionHourProfileBar(
                    hour: hour,
                    averageKWh: averageKWh,
                    totalCostKr: costs.reduce(0, +)
                )
            )
        }

        let bandCosts: [ConsumptionHourBandCost] = ConsumptionHourBand.allCases.map { band in
            let hours = bars.filter { ConsumptionHourBand.band(forHour: $0.hour) == band }
            return ConsumptionHourBandCost(
                band: band,
                costKr: hours.reduce(0) { $0 + $1.totalCostKr },
                energyKWh: hours.reduce(0) { $0 + $1.averageKWh }
            )
        }
        guard let dominant = bandCosts.max(by: { $0.costKr < $1.costKr }), dominant.costKr > 0 else {
            return nil
        }

        let spots = samples.map(\.spotOre).sorted()
        let expensiveCutoff = percentile(spots, expensiveSpotPercentile) ?? spots.last ?? .greatestFiniteMagnitude
        let expensiveSamples = samples.filter { $0.spotOre >= expensiveCutoff }
        let totalKWh = samples.reduce(0.0) { $0 + $1.kWh }
        let totalKr = samples.reduce(0.0) { $0 + $1.costKr }
        let expensiveKWh = expensiveSamples.reduce(0.0) { $0 + $1.kWh }
        let expensiveKr = expensiveSamples.reduce(0.0) { $0 + $1.costKr }

        let shiftTip = shiftTip(
            samples: samples,
            bandCosts: bandCosts,
            baseloadKW: baseloadKW,
            expensiveCutoff: expensiveCutoff,
            periodKind: periodKind,
            calendar: calendar
        )

        return ConsumptionDiurnalInsight(
            hourBars: bars,
            bands: bandCosts,
            dominantBand: dominant.band,
            expensiveShareKWh: totalKWh > 0 ? expensiveKWh / totalKWh : 0,
            expensiveShareKr: totalKr > 0 ? expensiveKr / totalKr : 0,
            shiftTip: shiftTip
        )
    }

    nonisolated private static func shiftTip(
        samples: [Sample],
        bandCosts: [ConsumptionHourBandCost],
        baseloadKW: Double,
        expensiveCutoff: Double,
        periodKind: ConsumptionInsightsPeriodKind,
        calendar: Calendar
    ) -> ConsumptionShiftTip? {
        guard let evening = bandCosts.first(where: { $0.band == .evening }),
              let night = bandCosts.first(where: { $0.band == .night }),
              evening.energyKWh > 0,
              night.energyKWh > 0 else {
            return nil
        }

        let eveningSamples = samples.filter { ConsumptionHourBand.band(forHour: calendar.component(.hour, from: $0.start)) == .evening }
        let nightSamples = samples.filter { ConsumptionHourBand.band(forHour: calendar.component(.hour, from: $0.start)) == .night }
        let eveningKWh = eveningSamples.reduce(0.0) { $0 + $1.kWh }
        let nightKWh = nightSamples.reduce(0.0) { $0 + $1.kWh }
        let eveningKr = eveningSamples.reduce(0.0) { $0 + $1.costKr }
        let nightKr = nightSamples.reduce(0.0) { $0 + $1.costKr }
        guard eveningKWh > 0, nightKWh > 0 else { return nil }

        let eveningPrice = eveningKr / eveningKWh
        let nightPrice = nightKr / nightKWh
        guard eveningPrice > nightPrice + 0.05 else { return nil }

        let expensiveEveningExtra = eveningSamples.reduce(0.0) { sum, sample in
            guard sample.spotOre >= expensiveCutoff else { return sum }
            return sum + max(0, sample.kWh - baseloadKW * sample.hours)
        }
        let shiftKWh = min(expensiveEveningExtra, eveningKWh * 0.35)
        let savedKr = shiftKWh * (eveningPrice - nightPrice)
        let minSave = periodKind == .day ? 2.0 : 10.0
        let minShift = periodKind == .day ? 1.0 : 5.0
        guard savedKr >= minSave, shiftKWh >= minShift else { return nil }

        return ConsumptionShiftTip(
            shiftKWh: shiftKWh,
            fromBand: .evening,
            toBand: .night,
            savedKr: savedKr
        )
    }

    // MARK: - Peak

    nonisolated private static func hourPeak(
        from samples: [Sample],
        costProfile: CostProfile,
        includeHypotheticalEffectTariff: Bool,
        calendar: Calendar
    ) -> ConsumptionPowerPeakInsight? {
        var hours: [Date: (kWh: Double, hours: Double)] = [:]
        for sample in samples {
            let hourStart = calendar.dateInterval(of: .hour, for: sample.start)?.start ?? sample.start
            let current = hours[hourStart] ?? (0, 0)
            hours[hourStart] = (current.kWh + sample.kWh, current.hours + sample.hours)
        }
        let ranked = hours.compactMap { start, value -> (Date, Double)? in
            let duration = max(value.hours, 0.01)
            return (start, value.kWh / min(duration, 1.5))
        }
        .sorted { $0.1 > $1.1 }

        guard let top = ranked.first else { return nil }
        let tariff = costProfile.effectTariff
        let billedKW: Double
        let usesAveragePeaks: Bool
        switch tariff?.model {
        case .averageTopThree:
            let take = ranked.prefix(3).map(\.1)
            billedKW = take.isEmpty ? top.1 : take.reduce(0, +) / Double(take.count)
            usesAveragePeaks = true
        case .averageTopFive:
            let take = ranked.prefix(5).map(\.1)
            billedKW = take.isEmpty ? top.1 : take.reduce(0, +) / Double(take.count)
            usesAveragePeaks = true
        default:
            billedKW = top.1
            usesAveragePeaks = false
        }
        let effectCost = TotalCostService.shared.hypotheticalMonthlyEffectTariffCostKr(
            peakKW: billedKW,
            profile: costProfile,
            include: includeHypotheticalEffectTariff
        )
        return ConsumptionPowerPeakInsight(
            hourStart: top.0,
            powerKW: top.1,
            effectTariffCostKr: effectCost,
            usesAveragePeaks: usesAveragePeaks,
            includeHypotheticalCost: includeHypotheticalEffectTariff
        )
    }

    // MARK: - Electric car guess

    /// Hours that look like charging. This is a guess, never a fact.
    ///
    /// A candidate hour sits at least `minimumExtraKW` (3 kW) above the
    /// existing night baseload, and not more than `maximumExtraKW` (13 kW)
    /// above it — around a 1-phase 3.7 kW or 3-phase 11 kW charger.
    /// At least two consecutive hours are required; a single quiet hour
    /// in between may be bridged into the same session.
    /// The hourly power must be fairly even (coefficient of variation at
    /// most 0.30). Sessions usually fall in the evening or night (17–07).
    /// A very even, high daytime block (at least 6 kW extra) is also kept,
    /// because it looks like three-phase charging.
    private static let evMinimumExtraKW = 3.0
    private static let evMaximumExtraKW = 13.0
    private static let evMinimumHours = 2
    private static let evMaximumGapHours = 1
    private static let evEvennessLimit = 0.30
    private static let evDaytimeExtraKW = 6.0
    private static let evDaytimeEvennessLimit = 0.20

    nonisolated private static func electricCarGuess(
        from samples: [Sample],
        baseloadKW: Double,
        calendar: Calendar
    ) -> ConsumptionEVChargingInsight? {
        let hours = hourlyTotals(from: samples, calendar: calendar)
        guard hours.count >= evMinimumHours else { return nil }

        var charging: [HourTotal] = []
        var groups: [[HourTotal]] = []

        func closeGroup() {
            guard !charging.isEmpty else { return }
            groups.append(charging)
            charging = []
        }

        for hour in hours {
            let extra = hour.kW - baseloadKW
            let isCandidate = extra >= evMinimumExtraKW && extra <= evMaximumExtraKW
            if isCandidate {
                if let last = charging.last {
                    let gap = hour.start.timeIntervalSince(last.end) / 3600
                    if gap > Double(evMaximumGapHours) + 0.05 {
                        closeGroup()
                    }
                }
                charging.append(hour)
            }
        }
        closeGroup()

        var sessions: [ConsumptionEVChargingSession] = []
        for group in groups {
            let chargingHours = group.filter { $0.kW - baseloadKW >= evMinimumExtraKW }
            guard chargingHours.count >= evMinimumHours else { continue }
            let powers = chargingHours.map(\.kW)
            let mean = powers.reduce(0, +) / Double(powers.count)
            guard mean > 0 else { continue }
            let variance = powers.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(powers.count)
            let cv = variance.squareRoot() / mean
            guard cv <= evEvennessLimit else { continue }

            let nightCount = chargingHours.filter { isEveningOrNight($0.start, calendar: calendar) }.count
            let nightShare = Double(nightCount) / Double(chargingHours.count)
            let meanExtra = mean - baseloadKW
            let looksLikeThreePhase = meanExtra >= evDaytimeExtraKW && cv <= evDaytimeEvennessLimit
            guard nightShare >= 0.5 || looksLikeThreePhase else { continue }

            let first = chargingHours.first!
            let last = chargingHours.last!
            sessions.append(
                ConsumptionEVChargingSession(
                    start: first.start,
                    end: last.end,
                    energyKWh: chargingHours.reduce(0) { $0 + $1.kWh },
                    extraEnergyKWh: chargingHours.reduce(0) { $0 + max(0, $1.kWh - baseloadKW * $1.hours) },
                    costKr: chargingHours.reduce(0) { $0 + $1.costKr },
                    averagePowerKW: mean
                )
            )
        }

        guard !sessions.isEmpty else { return nil }
        return ConsumptionEVChargingInsight(
            sessions: sessions,
            dayProfiles: evDayProfiles(sessions: sessions, hours: hours, calendar: calendar),
            baseloadKW: baseloadKW
        )
    }

    nonisolated private static func evDayProfiles(
        sessions: [ConsumptionEVChargingSession],
        hours: [HourTotal],
        calendar: Calendar
    ) -> [ConsumptionEVDayProfile] {
        var days: Set<Date> = []
        for session in sessions {
            days.insert(calendar.startOfDay(for: session.start))
            let lastInstant = session.end.addingTimeInterval(-1)
            days.insert(calendar.startOfDay(for: lastInstant))
        }
        let byStart = Dictionary(uniqueKeysWithValues: hours.map { ($0.start, $0) })
        return days.sorted().map { day in
            let bars = (0..<24).map { hour -> ConsumptionEVHourBar in
                let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
                let total = byStart[start]
                let isCharging = sessions.contains { session in
                    session.start <= start && start < session.end
                }
                return ConsumptionEVHourBar(
                    start: start,
                    kWh: total?.kWh ?? 0,
                    isCharging: isCharging
                )
            }
            return ConsumptionEVDayProfile(day: day, hours: bars)
        }
    }

    private struct HourTotal {
        let start: Date
        let end: Date
        let hours: Double
        let kWh: Double
        let kW: Double
        let costKr: Double
    }

    nonisolated private static func hourlyTotals(from samples: [Sample], calendar: Calendar) -> [HourTotal] {
        var buckets: [Date: (kWh: Double, cost: Double, hours: Double)] = [:]
        for sample in samples {
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: sample.start)
            guard let hourStart = calendar.date(from: components) else { continue }
            var bucket = buckets[hourStart] ?? (0, 0, 0)
            bucket.kWh += sample.kWh
            bucket.cost += sample.costKr
            bucket.hours += sample.hours
            buckets[hourStart] = bucket
        }
        return buckets.keys.sorted().compactMap { start in
            guard let bucket = buckets[start], bucket.hours >= 0.5 else { return nil }
            let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            return HourTotal(
                start: start,
                end: end,
                hours: 1,
                kWh: bucket.kWh,
                kW: bucket.kWh, // a full hour: kWh in one hour equals average kW
                costKr: bucket.cost
            )
        }
    }

    nonisolated private static func isEveningOrNight(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 17 || hour < 7
    }

    // MARK: - Summary

    nonisolated private static func summary(
        periodKind: ConsumptionInsightsPeriodKind,
        resolution: ConsumptionInsightsResolution,
        baseload: ConsumptionBaseloadInsight?,
        events: [ConsumptionLoadEvent],
        diurnal: ConsumptionDiurnalInsight?,
        powerPeak: ConsumptionPowerPeakInsight?,
        samples: [Sample]
    ) -> [String] {
        if resolution == .none {
            return ["Det finns inte tillräckligt med förbrukning sparad för att säga vad som drog."]
        }

        var sentences: [String] = []
        let totalKr = samples.reduce(0.0) { $0 + $1.costKr }

        if let baseload {
            if totalKr > 0 {
                let share = (baseload.costKr / totalKr) * 100
                if share >= 35 {
                    sentences.append(
                        "Det du alltid drar stod för ungefär \(wholeNumber(share)) % av kostnaden, ca \(wholeNumber(baseload.costKr)) kr."
                    )
                } else {
                    sentences.append(
                        "Det du alltid drar var ungefär \(powerPhrase(baseload.powerKW)) och kostade ca \(wholeNumber(baseload.costKr)) kr."
                    )
                }
            } else {
                sentences.append("Det du alltid drar var ungefär \(powerPhrase(baseload.powerKW)).")
            }
        }

        if let diurnal {
            let band = diurnal.dominantBand
            let bandCost = diurnal.bands.first { $0.band == band }?.costKr ?? 0
            if bandCost > 0 {
                sentences.append("Mest pengar gick på \(band.swedishName)en (\(wholeNumber(bandCost)) kr).")
            }
        }

        if let event = events.first {
            sentences.append(
                "Största toppen var \(powerPhrase(event.peakKW)), \(AppFormatters.sentenceWeekdayDayMonth(event.start))."
            )
        } else if let peak = powerPeak {
            sentences.append(
                "Högsta timmen var \(powerPhrase(peak.powerKW)), \(AppFormatters.sentenceDayMonthAndHour(peak.hourStart))."
            )
        }

        if sentences.isEmpty {
            if periodKind == .day {
                sentences.append("Det finns för lite mätning den här dagen för att säga vad som drog.")
            } else {
                sentences.append("Det finns för lite mätning den här perioden för att säga vad som drog.")
            }
        }

        return Array(sentences.prefix(3))
    }

    nonisolated private static func empty(
        periodKind: ConsumptionInsightsPeriodKind,
        periodStart: Date,
        periodEnd: Date,
        factors: ConsumptionInsightsFactors
    ) -> ConsumptionInsights {
        ConsumptionInsights(
            periodKind: periodKind,
            periodStart: periodStart,
            periodEnd: periodEnd,
            resolution: .none,
            factors: factors,
            summarySentences: ["Det finns inte tillräckligt med förbrukning sparad för att säga vad som drog."],
            baseload: nil,
            events: [],
            eventsUnavailableReason: "Förbrukning saknas.",
            diurnal: nil,
            diurnalUnavailableReason: "Förbrukning saknas.",
            powerPeak: nil,
            powerPeakUnavailableReason: "Förbrukning saknas.",
            evCharging: nil
        )
    }

    nonisolated static func powerPhrase(_ kW: Double) -> String {
        if kW < 1 {
            return "\(Int((kW * 1000).rounded())) W"
        }
        return "\(kW.formatted(.number.locale(AppFormatters.swedishLocale).precision(.fractionLength(1)))) kW"
    }

    nonisolated private static func wholeNumber(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.locale(AppFormatters.swedishLocale))
    }

    nonisolated static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let clamped = min(max(p, 0), 1)
        let idx = clamped * Double(sorted.count - 1)
        let lo = Int(idx.rounded(.down))
        let hi = min(Int(idx.rounded(.up)), sorted.count - 1)
        let weight = idx - Double(lo)
        return sorted[lo] * (1 - weight) + sorted[hi] * weight
    }
}

#if DEBUG
extension ConsumptionInsightsBuilder {
    /// Executable checks for baseload and event detection. There is no test target; previews call this.
    @discardableResult
    nonisolated static func debugVerifyAlgorithms() -> Bool {
        let calendar = Calendar.energyHistory
        let dayStart = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 0, minute: 0))!
        var intervals: [HistoricalEnergyIntervalValue] = []
        intervals.reserveCapacity(96)

        for index in 0..<96 {
            let start = dayStart.addingTimeInterval(Double(index) * 900)
            let end = start.addingTimeInterval(900)
            let hour = calendar.component(.hour, from: start)
            let minute = calendar.component(.minute, from: start)
            let kWh: Double
            if hour < 5 {
                kWh = (hour == 2 && minute == 0) ? 0.12 : 0.08
            } else if hour >= 9 && hour < 13 {
                kWh = 0.60
            } else if hour == 17 {
                kWh = 2.0
            } else {
                kWh = 0.10
            }
            intervals.append(
                HistoricalEnergyIntervalValue(
                    id: UUID(),
                    intervalStart: start,
                    intervalEnd: end,
                    spotPriceOrePerKWh: hour >= 17 ? 160 : 30,
                    consumptionKWh: kWh,
                    energyCostSEK: nil,
                    gridCostSEK: nil,
                    taxCostSEK: nil,
                    vatCostSEK: nil,
                    totalCostSEK: kWh * ((hour >= 17 ? 160 : 30) / 100 + 1.0)
                )
            )
        }

        let insights = make(
            intervals: intervals,
            previousIntervals: [],
            dailySummaries: [],
            costProfile: .swedishDefaultEstimate(),
            periodStart: dayStart,
            periodEnd: dayStart.addingTimeInterval(24 * 3600),
            now: dayStart.addingTimeInterval(24 * 3600),
            periodKind: .day
        )

        guard insights.resolution == .quarterHour else {
            assertionFailure("Expected quarter-hour resolution")
            return false
        }
        guard let baseload = insights.baseload else {
            assertionFailure("Expected a night baseload")
            return false
        }
        let expectedBaseloadKW = 0.32
        guard abs(baseload.powerKW - expectedBaseloadKW) < 0.08 else {
            assertionFailure("Baseload drifted: \(baseload.powerKW)")
            return false
        }

        let hasShortPeak = insights.events.contains { event in
            event.shape == .shortHighPeak && abs(event.peakKW - 8.0) < 0.2
        }
        let hasLongLoad = insights.events.contains { event in
            event.shape == .longEvenLoad && event.end.timeIntervalSince(event.start) >= 3 * 3600 - 60
        }
        guard hasShortPeak else {
            assertionFailure("Missing short high peak (oven-shaped)")
            return false
        }
        guard hasLongLoad else {
            assertionFailure("Missing long even load (charging-shaped)")
            return false
        }

        // Overlay a 4-hour 11 kW night charge so the EV guess can be checked.
        var evIntervals = intervals
        for evHour in [20, 21, 22, 23] {
            let evStart = calendar.date(bySettingHour: evHour, minute: 0, second: 0, of: dayStart)!
            for quarter in 0..<4 {
                let start = evStart.addingTimeInterval(Double(quarter) * 900)
                let end = start.addingTimeInterval(900)
                evIntervals.removeAll { $0.intervalStart == start }
                evIntervals.append(
                    HistoricalEnergyIntervalValue(
                        id: UUID(),
                        intervalStart: start,
                        intervalEnd: end,
                        spotPriceOrePerKWh: 20,
                        consumptionKWh: 2.75,
                        energyCostSEK: nil,
                        gridCostSEK: nil,
                        taxCostSEK: nil,
                        vatCostSEK: nil,
                        totalCostSEK: 2.75 * 1.2
                    )
                )
            }
        }
        evIntervals.sort { $0.intervalStart < $1.intervalStart }

        let hidden = make(
            intervals: evIntervals,
            previousIntervals: [],
            dailySummaries: [],
            costProfile: .swedishDefaultEstimate(),
            periodStart: dayStart,
            periodEnd: dayStart.addingTimeInterval(24 * 3600),
            now: dayStart.addingTimeInterval(24 * 3600),
            periodKind: .day,
            includeElectricCarGuess: false
        )
        guard hidden.evCharging == nil else {
            assertionFailure("EV guess should stay off until the setting is on")
            return false
        }

        let evInsights = make(
            intervals: evIntervals,
            previousIntervals: [],
            dailySummaries: [],
            costProfile: .swedishDefaultEstimate(),
            periodStart: dayStart,
            periodEnd: dayStart.addingTimeInterval(24 * 3600),
            now: dayStart.addingTimeInterval(24 * 3600),
            periodKind: .day,
            includeElectricCarGuess: true
        )
        guard let ev = evInsights.evCharging, ev.sessions.count == 1 else {
            assertionFailure("Expected one charging guess, got \(evInsights.evCharging?.sessions.count ?? 0)")
            return false
        }
        let session = ev.sessions[0]
        guard abs(session.averagePowerKW - 11) < 0.6, session.energyKWh >= 40 else {
            assertionFailure("Unexpected charging session \(session.averagePowerKW) kW, \(session.energyKWh) kWh")
            return false
        }
        return true
    }
}
#endif
