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


// MARK: - Daily outdoor temperature (Open-Meteo)

nonisolated struct TemperaturePlace: Identifiable, Equatable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    static let presets: [TemperaturePlace] = [
        TemperaturePlace(id: "vaggeryd", name: "Vaggeryd", latitude: 57.4981, longitude: 14.1486),
        TemperaturePlace(id: "skillingaryd", name: "Skillingaryd", latitude: 57.4304, longitude: 14.1039),
        TemperaturePlace(id: "jonkoping", name: "Jönköping", latitude: 57.7826, longitude: 14.1618),
        TemperaturePlace(id: "varnamo", name: "Värnamo", latitude: 57.1860, longitude: 14.0400),
        TemperaturePlace(id: "nassjo", name: "Nässjö", latitude: 57.6531, longitude: 14.6968),
        TemperaturePlace(id: "savsjo", name: "Sävsjö", latitude: 57.4033, longitude: 14.6650),
        TemperaturePlace(id: "goteborg", name: "Göteborg", latitude: 57.7089, longitude: 11.9746),
        TemperaturePlace(id: "skelleftea", name: "Skellefteå", latitude: 64.7506, longitude: 20.9528)
    ]

    static func place(id: String) -> TemperaturePlace {
        presets.first { $0.id == id } ?? presets[0]
    }

    static func defaultID(forDSO dso: String) -> String {
        switch dso {
        case "jonkoping": return "jonkoping"
        case "goteborg": return "goteborg"
        case "skelleftea": return "skelleftea"
        default: return "vaggeryd"
        }
    }
}

struct TemperatureSnapshot: Equatable, Sendable {
    var days: [Date: Double]
    var notice: FetchNotice?
}

@MainActor
final class DailyTemperatureService {
    static let shared = DailyTemperatureService()

    private static let cacheKey = "temperature_daily_cache_v1"
    private static let refreshInterval: TimeInterval = 6 * 60 * 60
    private static let defaults = UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard

    private var memory: CacheFile = .empty
    private var didLoad = false
    private var inFlight: [String: Task<TemperatureSnapshot, Never>] = [:]

    private init() {}

    func temperatures(
        from start: Date,
        to end: Date,
        place: TemperaturePlace,
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) async -> TemperatureSnapshot {
        let key = "\(place.id)|\(Self.dayKey(start, calendar: calendar))|\(Self.dayKey(end, calendar: calendar))"
        if let existing = inFlight[key] {
            return await existing.value
        }
        let task = Task<TemperatureSnapshot, Never> { [weak self] in
            await self?.load(from: start, to: end, place: place, now: now, calendar: calendar)
                ?? TemperatureSnapshot(days: [:], notice: FetchNotice.temperature(failure: .unknown, stale: false))
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return await task.value
    }

    private func load(
        from start: Date,
        to end: Date,
        place: TemperaturePlace,
        now: Date,
        calendar: Calendar
    ) async -> TemperatureSnapshot {
        loadMemoryIfNeeded()
        let needed = Self.days(from: start, to: end, calendar: calendar)
        guard let first = needed.first, let last = needed.last else {
            return TemperatureSnapshot(days: [:], notice: nil)
        }

        var entry = memory.places[place.id] ?? PlaceCache(latitude: place.latitude, longitude: place.longitude, days: [:], lastForecastAt: nil)
        var values = Self.parsed(entry.days, calendar: calendar)
        let missing = needed.filter { values[$0] == nil }
        let recentStart = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)) ?? now
        let recentStale = entry.lastForecastAt.map { now.timeIntervalSince($0) >= Self.refreshInterval } ?? true
        let needsRecent = needed.contains { $0 >= calendar.startOfDay(for: recentStart) } && recentStale

        do {
            if let oldestMissing = missing.first, let newestMissing = missing.last {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? last
                let archiveEnd = min(newestMissing, yesterday)
                if oldestMissing <= archiveEnd {
                    let fetched = try await fetchArchive(place: place, from: oldestMissing, to: archiveEnd, calendar: calendar)
                    for (day, temp) in fetched {
                        values[day] = temp
                    }
                }
            }
            if needsRecent || missing.contains(where: { $0 >= calendar.startOfDay(for: recentStart) }) {
                let fetched = try await fetchForecast(place: place, pastDays: 8, calendar: calendar)
                for (day, temp) in fetched {
                    values[day] = temp
                }
                entry.lastForecastAt = now
            }

            entry.latitude = place.latitude
            entry.longitude = place.longitude
            entry.days = Dictionary(uniqueKeysWithValues: values.map { (Self.dayKey($0.key, calendar: calendar), $0.value) })
            memory.places[place.id] = entry
            persist()

            let available = Dictionary(uniqueKeysWithValues: needed.compactMap { day in
                values[day].map { (day, $0) }
            })
            return TemperatureSnapshot(days: available, notice: nil)
        } catch {
            let failure = FetchFailure.classify(error)
            AppLog.history.error("Temperature fetch failed: \(failure.localizedDescription, privacy: .public)")
            let available = Dictionary(uniqueKeysWithValues: needed.compactMap { day in
                values[day].map { (day, $0) }
            })
            if available.isEmpty {
                return TemperatureSnapshot(days: [:], notice: .temperature(failure: failure, stale: false))
            }
            return TemperatureSnapshot(days: available, notice: .temperature(failure: failure, stale: true))
        }
    }

    private func fetchArchive(
        place: TemperaturePlace,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [Date: Double] {
        var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "start_date", value: Self.dayKey(start, calendar: calendar)),
            URLQueryItem(name: "end_date", value: Self.dayKey(end, calendar: calendar)),
            URLQueryItem(name: "daily", value: "temperature_2m_mean"),
            URLQueryItem(name: "timezone", value: "Europe/Stockholm")
        ]
        return try await fetch(url: components?.url)
    }

    private func fetchForecast(
        place: TemperaturePlace,
        pastDays: Int,
        calendar: Calendar
    ) async throws -> [Date: Double] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_mean"),
            URLQueryItem(name: "timezone", value: "Europe/Stockholm"),
            URLQueryItem(name: "past_days", value: String(pastDays)),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        return try await fetch(url: components?.url)
    }

    private func fetch(url: URL?) async throws -> [Date: Double] {
        guard let url else { throw FetchFailure.unknown }
        let (data, response) = try await NetworkSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 404 { throw FetchFailure.notFound }
            throw FetchFailure.server(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(OpenMeteoDailyResponse.self, from: data)
        if decoded.error == true {
            throw FetchFailure.decoding
        }
        return decoded.temperatures(calendar: .energyHistory)
    }

    private func loadMemoryIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let data = Self.defaults.data(forKey: Self.cacheKey),
           let file = try? JSONDecoder().decode(CacheFile.self, from: data) {
            memory = file
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(memory) {
            Self.defaults.set(data, forKey: Self.cacheKey)
        }
    }

    nonisolated static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    nonisolated static func date(fromKey key: String, calendar: Calendar) -> Date? {
        let bits = key.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: bits[0], month: bits[1], day: bits[2]))
    }

    nonisolated static func days(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard first <= last else { return [] }
        var result: [Date] = []
        var day = first
        while day <= last {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    nonisolated static func parsed(_ raw: [String: Double], calendar: Calendar) -> [Date: Double] {
        Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            date(fromKey: key, calendar: calendar).map { ($0, value) }
        })
    }

    private struct CacheFile: Codable {
        var places: [String: PlaceCache]
        static let empty = CacheFile(places: [:])
    }

    private struct PlaceCache: Codable {
        var latitude: Double
        var longitude: Double
        var days: [String: Double]
        var lastForecastAt: Date?
    }
}

private struct OpenMeteoDailyResponse: Decodable {
    var error: Bool?
    var reason: String?
    var daily: Daily?

    struct Daily: Decodable {
        var time: [String]
        var temperature_2m_mean: [Double?]
    }

    func temperatures(calendar: Calendar) -> [Date: Double] {
        guard let daily else { return [:] }
        var result: [Date: Double] = [:]
        for (index, key) in daily.time.enumerated() {
            guard index < daily.temperature_2m_mean.count,
                  let value = daily.temperature_2m_mean[index],
                  let day = DailyTemperatureService.date(fromKey: key, calendar: calendar) else {
                continue
            }
            result[day] = value
        }
        return result
    }
}
