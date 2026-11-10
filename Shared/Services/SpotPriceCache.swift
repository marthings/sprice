//
//  SpotPriceCache.swift
//  Spotprice
//
//  Persistent App Group cache for daily spot prices, shared by the app, backfill and widgets.
//

import Foundation
import OSLog

nonisolated enum SpotPriceCachePolicy {
    static let todayTTL: TimeInterval = 6 * 60 * 60
    static let tomorrowTTL: TimeInterval = 30 * 60
    static let minimumPersistedIntervals = 24
    static let folderName = "SpotPriceCache"
}

actor SpotPriceCache {
    static let shared = SpotPriceCache()

    private var memory: [String: SpotPriceCachePayload] = [:]
    private let calendar: Calendar
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(calendar: Calendar = .energyHistory) {
        self.calendar = calendar
    }

    func items(
        for day: Date,
        area: String,
        now: Date = Date(),
        allowStale: Bool = true
    ) -> [SpotPriceItem]? {
        let payload = loadPayload(for: day, area: area)
        guard let payload, !payload.items.isEmpty else {
            return nil
        }
        if isFresh(payload, now: now) {
            return payload.items
        }
        return allowStale ? payload.items : nil
    }

    func lookup(
        for day: Date,
        area: String,
        now: Date = Date(),
        allowStale: Bool = true
    ) -> [Date: Double]? {
        guard let items = items(for: day, area: area, now: now, allowStale: allowStale) else {
            return nil
        }
        return Self.lookup(from: items)
    }

    func store(_ items: [SpotPriceItem], area: String, now: Date = Date()) {
        guard items.count >= SpotPriceCachePolicy.minimumPersistedIntervals else {
            return
        }

        let grouped = Dictionary(grouping: items) { item in
            EnergyHistoryKey.dayKey(for: item.timeStart, calendar: calendar)
        }

        for (dayKey, dayItems) in grouped where !dayItems.isEmpty {
            let payload = SpotPriceCachePayload(area: area, dayKey: dayKey, items: dayItems, savedAt: now)
            memory[Self.memoryKey(area: area, dayKey: dayKey)] = payload
            persist(payload)
        }
    }

    func store(lookup: [Date: Double], day: Date, area: String, now: Date = Date()) {
        guard lookup.count >= SpotPriceCachePolicy.minimumPersistedIntervals else {
            return
        }

        let items = lookup.keys.sorted().map { start in
            SpotPriceItem(
                sekPerKWh: (lookup[start] ?? 0) / 100.0,
                eurPerKWh: 0,
                exr: 0,
                timeStart: start,
                timeEnd: start.addingTimeInterval(15 * 60)
            )
        }
        store(items, area: area, now: now)
    }

    /// Returns cached prices when they are still fresh. Callers must not cache failures.
    func cachedItemsIfFresh(for day: Date, area: String, now: Date = Date()) -> [SpotPriceItem]? {
        items(for: day, area: area, now: now, allowStale: false)
    }

    struct DayPayload: Sendable {
        let items: [SpotPriceItem]
        let savedAt: Date
        let isFresh: Bool
    }

    func payload(for day: Date, area: String, now: Date = Date()) -> DayPayload? {
        guard let stored = loadPayload(for: day, area: area), !stored.items.isEmpty else {
            return nil
        }
        return DayPayload(items: stored.items, savedAt: stored.savedAt, isFresh: isFresh(stored, now: now))
    }

    func cachedPayloadIfFresh(for day: Date, area: String, now: Date = Date()) -> DayPayload? {
        guard let payload = payload(for: day, area: area, now: now), payload.isFresh else {
            return nil
        }
        return payload
    }

    nonisolated static func lookup(from items: [SpotPriceItem]) -> [Date: Double] {
        var map: [Date: Double] = [:]
        map.reserveCapacity(items.count)
        for item in items {
            map[item.timeStart] = item.sekPerKWh * 100.0
        }
        return map
    }

    nonisolated static func timeToLive(
        for day: Date,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> TimeInterval? {
        let dayStart = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: now)
        if dayStart < today {
            return nil
        }
        if dayStart == today {
            return SpotPriceCachePolicy.todayTTL
        }
        return SpotPriceCachePolicy.tomorrowTTL
    }

    private func isFresh(_ payload: SpotPriceCachePayload, now: Date) -> Bool {
        guard let day = Self.date(fromDayKey: payload.dayKey, calendar: calendar) else {
            return false
        }
        guard let ttl = Self.timeToLive(for: day, now: now, calendar: calendar) else {
            return true
        }
        return now.timeIntervalSince(payload.savedAt) < ttl
    }

    private func loadPayload(for day: Date, area: String) -> SpotPriceCachePayload? {
        let dayKey = EnergyHistoryKey.dayKey(for: day, calendar: calendar)
        let key = Self.memoryKey(area: area, dayKey: dayKey)
        if let cached = memory[key], !cached.items.isEmpty {
            return cached
        }
        guard let url = Self.fileURL(area: area, dayKey: dayKey),
              let data = try? Data(contentsOf: url),
              let payload = try? decoder.decode(SpotPriceCachePayload.self, from: data),
              !payload.items.isEmpty else {
            return nil
        }
        memory[key] = payload
        return payload
    }

    private func persist(_ payload: SpotPriceCachePayload) {
        guard let data = try? encoder.encode(payload),
              let url = Self.fileURL(area: payload.area, dayKey: payload.dayKey) else {
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.spotPrice.error("Could not persist spot cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated private static func memoryKey(area: String, dayKey: String) -> String {
        "\(area)|\(dayKey)"
    }

    nonisolated private static func fileURL(area: String, dayKey: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: EnergyHistoryConstants.appGroupIdentifier)?
            .appendingPathComponent(SpotPriceCachePolicy.folderName, isDirectory: true)
            .appendingPathComponent(area, isDirectory: true)
            .appendingPathComponent("\(dayKey).json", isDirectory: false)
    }

    nonisolated private static func date(fromDayKey dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

nonisolated private struct SpotPriceCachePayload: Codable, Sendable {
    let area: String
    let dayKey: String
    let items: [SpotPriceItem]
    let savedAt: Date
}
