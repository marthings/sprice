//
//  EnergyHistoryRecorder.swift
//  Spotprice
//
//  Converts loaded price and energy data into local history records.
//

import Foundation
import OSLog

enum EnergyHistoryBackfillTiming {
    static let maxMonths = 24
    static let retryInterval: TimeInterval = 12 * 60 * 60
    static let monthDelay: Duration = .milliseconds(400)
    static let spotDelay: Duration = .milliseconds(150)
}

// MARK: - Energy History Recorder

@MainActor
final class EnergyHistoryRecorder {
    private struct ConsumptionInterval {
        let start: Date
        let end: Date
        let kWh: Double
        let hoursInPeriod: Double
    }

    private enum IntervalResolution {
        case quarterly
        case hourly
        case daily

        var source: HistoricalEnergySource {
            switch self {
            case .quarterly, .hourly:
                return .measuredConsumption
            case .daily:
                return .estimatedCost
            }
        }
    }

    private enum RecordResult {
        case recorded
        case empty
        case failed
    }

    private let store: EnergyHistoryStore
    private let writer: EnergyHistoryWriter?
    private let calendar: Calendar
    private let totalCostService: TotalCostService
    private var spotPriceCache: [String: [Date: Double]] = [:]
    private var pendingHistoryNotification: Task<Void, Never>?

    init(
        store: EnergyHistoryStore,
        writer: EnergyHistoryWriter? = nil,
        totalCostService: TotalCostService? = nil,
        calendar: Calendar? = nil
    ) {
        self.store = store
        self.writer = writer
        self.totalCostService = totalCostService ?? .shared
        self.calendar = calendar ?? .energyHistory
    }

    convenience init() throws {
        try self.init(store: EnergyHistoryStores.reader(), writer: EnergyHistoryStores.writer())
    }

    func recordPriceHistory(dayData: DayChartData, priceArea: String) {
        let drafts = dayData.buckets.map { bucket in
            HistoricalEnergyRecordDraft(
                intervalStart: bucket.start,
                intervalEnd: bucket.end,
                priceArea: priceArea,
                spotPriceOrePerKWh: bucket.orePerKWh,
                source: .spotPrice,
                confidence: .priceOnly,
                calendar: calendar
            )
        }

        guard !drafts.isEmpty else {
            return
        }

        Task {
            do {
                try await upsertRecords(drafts)
                AppLog.history.info("Recorded \(drafts.count) price intervals for \(priceArea, privacy: .public)")
            } catch {
                AppLog.history.error("Failed to record price history: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func recordCurrentMonthConsumptionHistory(
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        now: Date = Date()
    ) async {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            AppLog.history.error("Could not calculate current month start")
            return
        }

        let windowStart = now.addingTimeInterval(-48 * 60 * 60)
        var rangeStart = max(monthStart, windowStart)
        do {
            let monthKey = EnergyHistoryKey.monthKey(for: monthStart, calendar: calendar)
            let existingDays = try store.fetchDailySummaries(monthKey: monthKey, priceArea: priceArea)
                .filter { ($0.totalConsumptionKWh ?? 0) > 0 }
                .count
            if existingDays < 2 {
                rangeStart = monthStart
            }
        } catch {
            rangeStart = monthStart
        }

        _ = await recordConsumptionHistory(
            from: rangeStart,
            to: now,
            consumptionService: consumptionService,
            spotPriceService: spotPriceService,
            priceArea: priceArea,
            providerID: providerID,
            costProfile: costProfile,
            now: now
        )
    }

    @discardableResult
    func backfillPastConsumptionHistory(
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        now: Date = Date()
    ) async -> Bool {
        guard !providerID.isEmpty else { return true }
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return false
        }

        AppLog.history.info("Starting consumption history backfill for \(priceArea, privacy: .public) via \(providerID, privacy: .public)")

        for offset in 1...EnergyHistoryBackfillTiming.maxMonths {
            if Task.isCancelled { return false }
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else {
                break
            }
            guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
                break
            }

            do {
                if try isConsumptionComplete(for: monthStart, priceArea: priceArea) {
                    AppLog.history.info("Skipping complete history month \(EnergyHistoryKey.monthKey(for: monthStart), privacy: .public)")
                    continue
                }
            } catch {
                AppLog.history.error("Could not inspect stored month: \(error.localizedDescription, privacy: .public)")
                return false
            }

            let result = await recordConsumptionHistory(
                from: monthInterval.start,
                to: monthInterval.end,
                consumptionService: consumptionService,
                spotPriceService: spotPriceService,
                priceArea: priceArea,
                providerID: providerID,
                costProfile: costProfile,
                now: now
            )

            switch result {
            case .recorded:
                scheduleHistoryDidUpdate()
                try? await Task.sleep(for: EnergyHistoryBackfillTiming.monthDelay)
            case .empty:
                AppLog.history.info("No consumption for \(EnergyHistoryKey.monthKey(for: monthStart), privacy: .public), stopping backfill")
                return true
            case .failed:
                AppLog.history.error("Stopping consumption history backfill after a failed month")
                return false
            }
        }

        AppLog.history.info("Finished consumption history backfill")
        return true
    }

    @discardableResult
    private func recordConsumptionHistory(
        from startDate: Date,
        to endDate: Date,
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        now: Date
    ) async -> RecordResult {
        do {
            let fetched = try await fetchConsumptionIntervals(
                consumptionService: consumptionService,
                startDate: startDate,
                endDate: endDate
            )

            let intervals = fetched.intervals.filter { interval in
                interval.start >= startDate && interval.start < endDate && interval.kWh > 0
            }
            guard !intervals.isEmpty else {
                return .empty
            }

            let spotPriceLookup = await fetchSpotPriceLookup(
                for: intervals,
                spotPriceService: spotPriceService,
                priceArea: priceArea,
                throttle: calendar.dateInterval(of: .month, for: startDate)?.start != calendar.dateInterval(of: .month, for: now)?.start
            )
            let snapshot = HistoricalCostProfileSnapshot(profile: costProfile, capturedAt: now)

            let matchedIntervals = intervals.compactMap { interval -> (interval: ConsumptionInterval, spotPriceOre: Double)? in
                guard let spotPriceOre = representativeSpotPrice(for: interval, in: spotPriceLookup) else {
                    return nil
                }
                return (interval, spotPriceOre)
            }
            guard !matchedIntervals.isEmpty else {
                AppLog.history.warning("Consumption had no matching spot prices")
                return .empty
            }

            let confidence: HistoricalEnergyConfidence
            switch fetched.resolution {
            case .daily:
                confidence = .estimated
            case .quarterly, .hourly:
                confidence = matchedIntervals.count == intervals.count ? .measured : .partial
            }

            let drafts = matchedIntervals.map { matched in
                let cost = totalCostService.calculateTotalCost(
                    kWh: matched.interval.kWh,
                    spotPriceOre: matched.spotPriceOre,
                    profile: costProfile,
                    hoursInPeriod: matched.interval.hoursInPeriod
                )

                return HistoricalEnergyRecordDraft(
                    intervalStart: matched.interval.start,
                    intervalEnd: matched.interval.end,
                    priceArea: priceArea,
                    providerID: providerID,
                    spotPriceOrePerKWh: matched.spotPriceOre,
                    consumptionKWh: matched.interval.kWh,
                    energyCostSEK: cost.providerTotalKr,
                    gridCostSEK: cost.gridTotalKr,
                    taxCostSEK: cost.taxesAndFeesKr,
                    vatCostSEK: cost.vatKr,
                    totalCostSEK: cost.totalKr,
                    costProfileSnapshot: snapshot,
                    source: fetched.resolution.source,
                    confidence: confidence,
                    calendar: calendar
                )
            }

            try await upsertRecords(drafts)
            AppLog.history.info(
                "Recorded \(drafts.count)/\(intervals.count) consumption intervals for \(priceArea, privacy: .public) via \(providerID, privacy: .public)"
            )
            return .recorded
        } catch let error as ConsumptionError {
            switch error {
            case .notFound:
                return .empty
            case .unauthorized, .missingCredentials:
                AppLog.history.error("Consumption history credentials failed: \(error.localizedDescription, privacy: .public)")
                return .failed
            default:
                AppLog.history.error("Failed to record consumption history: \(error.localizedDescription, privacy: .public)")
                return .failed
            }
        } catch {
            AppLog.history.error("Failed to record consumption history: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private func fetchConsumptionIntervals(
        consumptionService: ConsumptionService,
        startDate: Date,
        endDate: Date
    ) async throws -> (intervals: [ConsumptionInterval], resolution: IntervalResolution) {
        do {
            let quarterly = try await consumptionService.fetchQuarterlyConsumption(startDate: startDate, endDate: endDate)
            if !quarterly.isEmpty {
                return (
                    quarterly.map { entry in
                        ConsumptionInterval(
                            start: entry.date,
                            end: calendar.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(15 * 60),
                            kWh: entry.kWh,
                            hoursInPeriod: 0.25
                        )
                    },
                    .quarterly
                )
            }
        } catch let error as ConsumptionError {
            try rethrowCredentialError(error)
            AppLog.history.notice("Quarterly consumption unavailable, trying hourly")
        } catch {
            AppLog.history.notice("Quarterly consumption unavailable, trying hourly: \(error.localizedDescription, privacy: .public)")
        }

        do {
            let hourly = try await consumptionService.fetchHourlyConsumption(startDate: startDate, endDate: endDate)
            if !hourly.isEmpty {
                return (
                    hourly.map { entry in
                        ConsumptionInterval(
                            start: entry.date,
                            end: calendar.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(60 * 60),
                            kWh: entry.kWh,
                            hoursInPeriod: 1.0
                        )
                    },
                    .hourly
                )
            }
        } catch let error as ConsumptionError {
            try rethrowCredentialError(error)
            AppLog.history.notice("Hourly consumption unavailable, trying daily")
        } catch {
            AppLog.history.notice("Hourly consumption unavailable, trying daily: \(error.localizedDescription, privacy: .public)")
        }

        let year = calendar.component(.year, from: startDate)
        let month = calendar.component(.month, from: startDate)
        let daily = try await consumptionService.fetchDailyConsumption(year: year, month: month)
        let intervals = daily.compactMap { entry -> ConsumptionInterval? in
            let dayStart = calendar.startOfDay(for: entry.date)
            guard dayStart >= startDate && dayStart < endDate else { return nil }
            return ConsumptionInterval(
                start: dayStart,
                end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60),
                kWh: entry.kWh,
                hoursInPeriod: 24
            )
        }
        return (intervals, .daily)
    }

    private func fetchSpotPriceLookup(
        for intervals: [ConsumptionInterval],
        spotPriceService: SpotPriceService,
        priceArea: String,
        throttle _: Bool
    ) async -> [Date: Double] {
        let days = Set(intervals.map { calendar.startOfDay(for: $0.start) }).sorted()
        var lookup: [Date: Double] = [:]
        lookup.reserveCapacity(days.count * 96)

        await withTaskGroup(of: (Date, [Date: Double]).self) { group in
            var iterator = days.makeIterator()
            let limit = 4

            func enqueue() {
                guard let day = iterator.next() else { return }
                group.addTask {
                    let prices = await self.spotPrices(
                        for: day,
                        area: priceArea,
                        service: spotPriceService
                    )
                    return (day, prices)
                }
            }

            for _ in 0..<min(limit, days.count) {
                enqueue()
            }

            for await (_, dayPrices) in group {
                for (start, ore) in dayPrices {
                    lookup[start] = ore
                }
                enqueue()
            }
        }

        return lookup
    }

    private func spotPrices(
        for day: Date,
        area: String,
        service: SpotPriceService
    ) async -> [Date: Double] {
        let key = "\(area)|\(EnergyHistoryKey.dayKey(for: day, calendar: calendar))"
        if let cached = spotPriceCache[key], !cached.isEmpty {
            return cached
        }

        if let disk = SpotPriceDayCache.lookup(for: day, area: area, calendar: calendar), !disk.isEmpty {
            spotPriceCache[key] = disk
            return disk
        }

        do {
            let items = try await service.fetchSpotPrices(for: day, area: area)
            var map: [Date: Double] = [:]
            for item in items {
                map[item.timeStart] = item.sekPerKWh * 100.0
            }
            if !map.isEmpty {
                spotPriceCache[key] = map
            }
            return map
        } catch {
            AppLog.history.error("Failed to fetch spot prices for \(day, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func upsertRecords(_ drafts: [HistoricalEnergyRecordDraft]) async throws {
        if let writer {
            try await writer.upsertRecords(drafts)
        } else {
            try store.upsertRecords(drafts)
        }
    }

    private func scheduleHistoryDidUpdate() {
        pendingHistoryNotification?.cancel()
        pendingHistoryNotification = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: .energyHistoryDidUpdate, object: nil)
        }
    }

    private func representativeSpotPrice(for interval: ConsumptionInterval, in lookup: [Date: Double]) -> Double? {
        if interval.hoursInPeriod >= 24 {
            let dayPrices = lookup.compactMap { start, ore -> Double? in
                calendar.isDate(start, inSameDayAs: interval.start) ? ore : nil
            }
            guard !dayPrices.isEmpty else { return nil }
            return dayPrices.reduce(0, +) / Double(dayPrices.count)
        }

        guard let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: interval.start)) else {
            return nil
        }
        return lookup[hourStart]
    }

    private func rethrowCredentialError(_ error: ConsumptionError) throws {
        switch error {
        case .unauthorized, .missingCredentials:
            throw error
        default:
            return
        }
    }

    private func isConsumptionComplete(for monthStart: Date, priceArea: String) throws -> Bool {
        let monthKey = EnergyHistoryKey.monthKey(for: monthStart, calendar: calendar)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let requiredDays = max(daysInMonth - 1, 1)
        let daysWithUse = try store.fetchDailySummaries(monthKey: monthKey, priceArea: priceArea)
            .filter { ($0.totalConsumptionKWh ?? 0) > 0 }
            .count
        return daysWithUse >= requiredDays
    }
}

// MARK: - Backfill controller

@MainActor
final class EnergyHistoryBackfillController {
    static let shared = EnergyHistoryBackfillController()

    private var recorder: EnergyHistoryRecorder?
    private var inFlight: Task<Void, Never>?

    private static let defaults = UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard
    private static let lastSuccessKey = "energyHistory.backfill.lastSuccessAt"

    func runIfNeeded(
        recorder: EnergyHistoryRecorder? = nil,
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        now: Date = Date()
    ) async {
        guard !providerID.isEmpty else { return }

        if let inFlight {
            await inFlight.value
            return
        }

        if let lastSuccess = Self.defaults.object(forKey: Self.lastSuccessKey) as? Date,
           now.timeIntervalSince(lastSuccess) < EnergyHistoryBackfillTiming.retryInterval {
            return
        }

        if let recorder {
            self.recorder = recorder
        }
        let activeRecorder: EnergyHistoryRecorder
        if let existing = self.recorder {
            activeRecorder = existing
        } else if let created = try? EnergyHistoryRecorder() {
            self.recorder = created
            activeRecorder = created
        } else {
            AppLog.history.error("Could not open history store for backfill")
            return
        }

        let task = Task {
            let succeeded = await activeRecorder.backfillPastConsumptionHistory(
                consumptionService: consumptionService,
                spotPriceService: spotPriceService,
                priceArea: priceArea,
                providerID: providerID,
                costProfile: costProfile,
                now: now
            )
            if succeeded {
                Self.defaults.set(Date(), forKey: Self.lastSuccessKey)
            }
        }
        inFlight = task
        await task.value
        inFlight = nil
    }
}
