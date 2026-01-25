//
//  SpotPriceViewModel.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//
import SwiftUI
import Combine

@MainActor
final class SpotPriceViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(CurrentAndDay)  // carries current display text and chart-ready day data
        case failed(String)
    }
    
    struct CurrentAndDay: Equatable {
        let currentDisplay: String
        let day: DayChartData
    }
    
    struct DayChartData: Equatable {
        let buckets: [PriceBucket]
        let thresholds: Thresholds
        let minOre: Double
        let maxOre: Double
        
        var currentBucket: PriceBucket? {
            let now = Date()
            return buckets.first { $0.start <= now && $0.end > now }
        }
    }
    
    enum PriceCategory: String, Equatable, CaseIterable {
        case low
        case medium
        case high
    }
    
    struct Thresholds: Equatable {
        // Tertile cutoffs in öre/kWh used for classification
        let lowUpper: Double   // <= this is low
        let mediumUpper: Double // <= this is medium, above is high
    }
    
    struct PriceBucket: Identifiable, Equatable {
        let id: UUID
        let start: Date
        let end: Date
        let orePerKWh: Double
        let category: PriceCategory
        
        init(start: Date, end: Date, orePerKWh: Double, category: PriceCategory, id: UUID = UUID()) {
            self.start = start
            self.end = end
            self.orePerKWh = orePerKWh
            self.category = category
            self.id = id
        }
    }
    
    @Published private(set) var state: State = .idle
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let numberFormatter: NumberFormatter
    private let area: String
    private let nowProvider: () -> Date
    
    // Periodisk uppdaterings-Task
    private var refreshTask: Task<Void, Never>?
    // Konfigurerbart intervall (default 15 min)
    private let refreshInterval: Duration
    
    init(
        session: URLSession = .shared,
        area: String = "SE3",
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .gmt,
        calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            return cal
        }(),
        numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.locale = .current
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            return formatter
        }(),
        now: @escaping () -> Date = { Date() },
        refreshInterval: Duration = .seconds(900)
    ) {
        self.session = session
        self.area = area
        self.timeZone = timeZone
        self.calendar = calendar
        self.numberFormatter = numberFormatter
        self.nowProvider = now
        self.refreshInterval = refreshInterval
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        
        // Starta periodisk uppdatering direkt
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    func load() async {
        // Avoid redundant loads
        if case .loading = state { return }
        state = .loading
        
        do {
            let now = nowProvider()
            let url = try Self.endpointURL(for: now, area: area, timeZone: timeZone, calendar: calendar)
            let (data, response) = try await session.data(from: url)
            try Self.validate(response: response)
            
            let items = try decoder.decode([SpotPriceItem].self, from: data)
            
            // Build current display text
            let currentDisplay = try Self.makeDisplayText(
                from: items,
                now: now,
                calendar: calendar,
                formatter: numberFormatter
            )
            
            // Build chart-ready day data
            let dayData = try Self.makeDayChartData(
                from: items,
                for: now,
                calendar: calendar
            )
            
            state = .loaded(CurrentAndDay(currentDisplay: currentDisplay, day: dayData))
        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch {
            state = .failed("Ett oväntat fel inträffade. Försök igen senare.")
        }
    }
    
    // MARK: - Periodisk uppdatering
    
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // Kör en initial laddning direkt
            await self.load()
            // Kör därefter var 15:e minut tills Task avbryts
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    // Avbruten sömn -> avsluta loopen
                    break
                }
                if Task.isCancelled { break }
                await self.load()
            }
        }
    }
    
    // MARK: - Pure helpers (testable)
    
    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DisplayableError("Ogiltigt serversvar.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DisplayableError("Servern svarade med fel (\(http.statusCode)).")
        }
    }
    
    private static func endpointURL(for date: Date, area: String, timeZone: TimeZone, calendar: Calendar) throws -> URL {
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
    
    private static func makeDisplayText(from items: [SpotPriceItem], now: Date, calendar: Calendar, formatter: NumberFormatter) throws -> String {
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
    
    // MARK: - Chart derivation
    
    private static func makeDayChartData(from items: [SpotPriceItem], for now: Date, calendar: Calendar) throws -> DayChartData {
        // Filter items for the day of 'now'
        let dayItems = items.filter { calendar.isDate($0.timeStart, inSameDayAs: now) || calendar.isDate($0.timeEnd, inSameDayAs: now) }
        guard !dayItems.isEmpty else {
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
    
    private static func computeTertileThresholds(values: [Double]) -> Thresholds {
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

struct SpotPriceItem: Decodable, Equatable {
    let sekPerKWh: Double
    let eurPerKWh: Double
    let exr: Double
    let timeStart: Date
    let timeEnd: Date
    
    private enum CodingKeys: String, CodingKey {
        case sekPerKWh = "SEK_per_kWh"
        case eurPerKWh = "EUR_per_kWh"
        case exr = "EXR"
        case timeStart = "time_start"
        case timeEnd = "time_end"
    }
}

// MARK: - Lightweight error type for user-facing messages

struct DisplayableError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
