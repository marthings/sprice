//
//  ContentView.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//

import SwiftUI
import Combine

struct ContentView: View {
    
    @StateObject private var viewModel = SpotPriceViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .idle, .loading:
                Text("Hämtar spotpris…")
                    .foregroundStyle(.secondary)
            case .loaded(let display):
                Text("Spotpriset nu: \(display)")
                    .font(.title3)
                    .bold()
            case .failed(let errorText):
                VStack(spacing: 8) {
                    Text("Kunde inte hämta spotpris")
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Försök igen") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(48)
        .task {
            await viewModel.load()
        }
    }
}

@MainActor
final class SpotPriceViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(String)  // formatted display text
        case failed(String)
    }
    
    @Published private(set) var state: State = .idle
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let numberFormatter: NumberFormatter
    private let area: String
    private let nowProvider: () -> Date
    
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
        now: @escaping () -> Date = { Date() }
    ) {
        self.session = session
        self.area = area
        self.timeZone = timeZone
        self.calendar = calendar
        self.numberFormatter = numberFormatter
        self.nowProvider = now
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
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
            let display = try Self.makeDisplayText(
                from: items,
                now: now,
                calendar: calendar,
                formatter: numberFormatter
            )
            state = .loaded(display)
        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch {
            state = .failed("Ett oväntat fel inträffade. Försök igen senare.")
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
        return "\(formatted) öre/kWh"
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

#Preview {
    ContentView()
}
