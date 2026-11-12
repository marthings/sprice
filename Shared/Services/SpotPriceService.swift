//
//  SpotPriceService.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-31.
//

import Foundation
import OSLog

// MARK: - SpotPriceService

struct SpotPriceService: Sendable {
    private let session: URLSession
    private let timeZone: TimeZone
    private let calendar: Calendar

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    init(
        session: URLSession = NetworkSession.shared,
        timeZone: TimeZone = AppFormatters.swedishTimeZone,
        calendar: Calendar = AppFormatters.energyCalendar
    ) {
        self.session = session
        self.timeZone = timeZone
        self.calendar = calendar
    }
    
    /// Fetches spot prices for the given date and returns raw items
    func fetchSpotPrices(for date: Date = Date()) async throws -> [SpotPriceItem] {
        let area = await MainActor.run { ConsumptionSettings.shared.priceArea }
        return try await fetchSpotPrices(for: date, area: area)
    }

    /// Fetches spot prices for the given date and price area.
    func fetchSpotPrices(for date: Date = Date(), area: String, ignoreCache: Bool = false) async throws -> [SpotPriceItem] {
        try await fetchSpotPricesReporting(for: date, area: area, ignoreCache: ignoreCache).items
    }

    /// Fetches spot prices and reports whether stale cache was used after a failure.
    func fetchSpotPricesReporting(
        for date: Date = Date(),
        area: String,
        ignoreCache: Bool = false
    ) async throws -> SpotPriceFetchReport {
        // Demo mode: generated prices. No network, and the saved price cache is left alone.
        if DemoMode.isActive {
            return SpotPriceFetchReport(
                items: DemoData.priceItems(for: date),
                savedAt: Date(),
                usedStaleCache: false,
                failure: nil
            )
        }
        if !ignoreCache, let cached = await SpotPriceCache.shared.cachedPayloadIfFresh(for: date, area: area) {
            return SpotPriceFetchReport(
                items: cached.items,
                savedAt: cached.savedAt,
                usedStaleCache: false,
                failure: nil
            )
        }

        do {
            let url = try endpointURL(for: date, area: area, timeZone: timeZone, calendar: calendar)
            let (data, response) = try await session.data(from: url)
            try validate(response: response)

            let items = try decoder.decode([SpotPriceItem].self, from: data)
            guard !items.isEmpty else {
                throw FetchFailure.empty
            }
            let now = Date()
            await SpotPriceCache.shared.store(items, area: area, now: now)
            AppLog.spotPrice.info("Fetched \(items.count) price items")
            return SpotPriceFetchReport(
                items: items,
                savedAt: now,
                usedStaleCache: false,
                failure: nil
            )
        } catch {
            let failure = FetchFailure.classify(error)
            if let stale = await SpotPriceCache.shared.payload(for: date, area: area), !stale.items.isEmpty {
                AppLog.spotPrice.error("Using stale spot cache after fetch failure: \(failure.localizedDescription, privacy: .public)")
                return SpotPriceFetchReport(
                    items: stale.items,
                    savedAt: stale.savedAt,
                    usedStaleCache: true,
                    failure: failure
                )
            }
            throw failure
        }
    }

    func cachedOrFetchedDayChart(for date: Date, area: String) async -> DayChartData? {
        if DemoMode.isActive {
            return try? makeDayChartData(from: DemoData.priceItems(for: date), for: date)
        }
        if let cached = await SpotPriceCache.shared.items(for: date, area: area), !cached.isEmpty {
            return try? makeDayChartData(from: cached, for: date)
        }
        do {
            let items = try await fetchSpotPrices(for: date, area: area)
            return try? makeDayChartData(from: items, for: date)
        } catch {
            return nil
        }
    }
    
    /// Creates display text for the current price
    func makeDisplayText(
        from items: [SpotPriceItem],
        now: Date = Date(),
        formatter: NumberFormatter
    ) throws -> String {
        let todayItems = items.filter { calendar.isDate($0.timeStart, inSameDayAs: now) || calendar.isDate($0.timeEnd, inSameDayAs: now) }

        guard !todayItems.isEmpty else {
            throw DisplayableError("Inga prisdata hittades för idag.")
        }

        // Prefer the interval that contains 'now'; else latest past; else last today
        let containingNow = todayItems.first(where: { $0.timeStart <= now && now < $0.timeEnd })
        let latestPast = todayItems.filter { $0.timeEnd <= now }.max(by: { $0.timeEnd < $1.timeEnd })
        let chosen = containingNow ?? latestPast ?? todayItems.max(by: { $0.timeEnd < $1.timeEnd })

        guard let current = chosen else {
            throw DisplayableError("Kunde inte välja ett relevant prisintervall.")
        }

        let ore = current.sekPerKWh * 100.0
        let formatted = formatter.string(from: NSNumber(value: ore)) ?? String(format: "%.1f", ore)
        return "\(formatted)"
    }
    
    /// Creates chart-ready day data from spot price items
    func makeDayChartData(from items: [SpotPriceItem], for now: Date = Date()) throws -> DayChartData {
        let dayItems = items.filter { calendar.isDate($0.timeStart, inSameDayAs: now) || calendar.isDate($0.timeEnd, inSameDayAs: now) }

        guard !dayItems.isEmpty else {
            AppLog.spotPrice.error("No price items match selected day")
            throw DisplayableError("Inga prisdata hittades för idag.")
        }
        
        // Convert to öre
        let ores: [Double] = dayItems.map { $0.sekPerKWh * 100.0 }
        let minOre = ores.min() ?? 0
        let maxOre = ores.max() ?? 0
        
        // Compute tertile thresholds (adaptive)
        let thresholds = computeTertileThresholds(values: ores)
        
        // Classify into buckets
        let buckets: [PriceBucket] = dayItems
            .sorted(by: { $0.timeStart < $1.timeStart })
            .map { item in
                let ore = item.sekPerKWh * 100.0
                let cat: PriceCategory
                if ore <= thresholds.lowUpper {
                    cat = .low
                } else if ore <= thresholds.mediumUpper {
                    cat = .medium
                } else {
                    cat = .high
                }
                return PriceBucket(start: item.timeStart, end: item.timeEnd, orePerKWh: ore, category: cat)
            }
        
        return DayChartData(buckets: buckets, thresholds: thresholds, minOre: minOre, maxOre: maxOre)
    }
    
    // MARK: - Private helpers
    
    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FetchFailure.unknown
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw FetchFailure.notFound
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw FetchFailure.unauthorized
            }
            throw FetchFailure.server(http.statusCode)
        }
    }
    
    private func endpointURL(for date: Date, area: String, timeZone: TimeZone, calendar: Calendar) throws -> URL {
        // Format: https://www.elprisetjustnu.se/api/v1/prices/YYYY/MM-DD_AREA.json
        var cal = calendar
        cal.timeZone = timeZone
        let comps = cal.dateComponents(in: timeZone, from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            throw DisplayableError("Kunde inte skapa datum för förfrågan.")
        }
        let monthStr = String(format: "%02d", month)
        let dayStr = String(format: "%02d", day)
        let path = "https://www.elprisetjustnu.se/api/v1/prices/\(year)/\(monthStr)-\(dayStr)_\(area).json"
        guard let url = URL(string: path) else {
            throw DisplayableError("Kunde inte skapa URL för prisförfrågan.")
        }
        return url
    }
    
    private func computeTertileThresholds(values: [Double]) -> Thresholds {
        guard !values.isEmpty else { return Thresholds(lowUpper: 0, mediumUpper: 0) }
        let sorted = values.sorted()
        // Positions for 33rd and 66th percentile (inclusive)
        let lowIndex = max(0, min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.33)))
        let medIndex = max(0, min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.66)))
        let lowUpper = sorted[lowIndex]
        let mediumUpper = max(lowUpper, sorted[medIndex]) // ensure non-decreasing cutoffs
        return Thresholds(lowUpper: lowUpper, mediumUpper: mediumUpper)
    }
}


nonisolated struct SpotPriceFetchReport: Sendable {
    let items: [SpotPriceItem]
    let savedAt: Date
    let usedStaleCache: Bool
    let failure: FetchFailure?
}
