//
//  SpotPriceModels.swift
//  Spotprice
//
//  Core data models for spot price functionality
//

import Foundation

// MARK: - Price Category

nonisolated enum PriceCategory: String, Equatable, CaseIterable, Sendable {
    case low
    case medium
    case high

    /// Swedish label for accessibility
    var label: String {
        switch self {
        case .low: return "Lågt"
        case .medium: return "Medel"
        case .high: return "Högt"
        }
    }

    /// SF Symbol that works for colorblind users
    var accessibilityIcon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }

    /// Compact icon for tight spaces
    var compactIcon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }
}

// MARK: - Thresholds

nonisolated struct Thresholds: Equatable, Sendable {
    /// Tertile cutoffs in öre/kWh used for classification
    let lowUpper: Double   // <= this is low
    let mediumUpper: Double // <= this is medium, above is high
}

// MARK: - Price Bucket

nonisolated struct PriceBucket: Identifiable, Equatable, Sendable {
    let start: Date
    let end: Date
    let orePerKWh: Double
    let category: PriceCategory

    var id: Date { start }

    init(start: Date, end: Date, orePerKWh: Double, category: PriceCategory) {
        self.start = start
        self.end = end
        self.orePerKWh = orePerKWh
        self.category = category
    }
}

// MARK: - Day Chart Data

nonisolated struct DayChartData: Equatable, Sendable {
    let buckets: [PriceBucket]
    let thresholds: Thresholds
    let minOre: Double
    let maxOre: Double

    var currentBucket: PriceBucket? {
        currentBucket(at: Date())
    }

    func currentBucket(at date: Date) -> PriceBucket? {
        buckets.first { $0.start <= date && $0.end > date }
    }

    func currentBucketIndex(at date: Date = Date()) -> Int? {
        if let index = buckets.firstIndex(where: { $0.start <= date && $0.end > date }) {
            return index
        }
        if let lastPastIndex = buckets.indices.filter({ buckets[$0].end <= date }).last {
            return lastPastIndex
        }
        return buckets.indices.first
    }
}

// MARK: - Widget Timeline

nonisolated enum WidgetTimelineSchedule {
    /// Next quarter-hour boundary for widget timeline refresh policy.
    static func nextQuarterHourUpdate(from date: Date = Date(), calendar: Calendar = .energyHistory) -> Date {
        let minute = calendar.component(.minute, from: date)
        let minutesToNextQuarter = 15 - (minute % 15)
        return calendar.date(byAdding: .minute, value: minutesToNextQuarter, to: date)
            ?? date.addingTimeInterval(15 * 60)
    }

    /// Tomorrow's day-ahead prices typically publish around 13:00 Europe/Stockholm.
    static func nextDayAheadRefresh(from date: Date = Date(), calendar: Calendar = .energyHistory) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 13
        components.minute = 15
        components.second = 0
        let todayPublication = calendar.date(from: components) ?? date
        if date < todayPublication {
            return todayPublication
        }
        return calendar.date(byAdding: .day, value: 1, to: todayPublication)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    static func remainingBuckets(
        today: DayChartData,
        tomorrow: DayChartData?,
        now: Date
    ) -> [(date: Date, bucket: PriceBucket, day: DayChartData)] {
        var result: [(Date, PriceBucket, DayChartData)] = []
        for bucket in today.buckets where bucket.end > now {
            result.append((max(bucket.start, now), bucket, today))
        }
        if let tomorrow {
            for bucket in tomorrow.buckets {
                result.append((bucket.start, bucket, tomorrow))
            }
        }
        if result.isEmpty, let current = today.currentBucket(at: now) {
            result.append((now, current, today))
        }
        return result
    }
}

// MARK: - Price Bucket Analytics

nonisolated enum SpotPriceMatching: Sendable {
    nonisolated static func price(
        for intervalStart: Date,
        hoursInPeriod: Double,
        lookup: [Date: Double],
        calendar: Calendar
    ) -> Double? {
        if hoursInPeriod >= 23 {
            let dayPrices = lookup.compactMap { start, ore -> Double? in
                calendar.isDate(start, inSameDayAs: intervalStart) ? ore : nil
            }
            return average(dayPrices)
        }

        if hoursInPeriod <= 0.4 {
            if let exact = lookup[intervalStart] {
                return exact
            }
            return hourAverage(for: intervalStart, lookup: lookup, calendar: calendar)
        }

        return hourAverage(for: intervalStart, lookup: lookup, calendar: calendar)
            ?? lookup[intervalStart]
    }

    nonisolated private static func hourAverage(
        for intervalStart: Date,
        lookup: [Date: Double],
        calendar: Calendar
    ) -> Double? {
        guard let hourStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour], from: intervalStart)
        ) else {
            return nil
        }

        var quarters: [Double] = []
        quarters.reserveCapacity(4)
        for offset in 0..<4 {
            guard let start = calendar.date(byAdding: .minute, value: offset * 15, to: hourStart) else {
                continue
            }
            if let ore = lookup[start] {
                quarters.append(ore)
            }
        }
        if let averaged = average(quarters) {
            return averaged
        }
        return lookup[hourStart]
    }

    nonisolated private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

nonisolated enum PriceBucketAnalytics {
    static func averageSpotPrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}

// MARK: - Spot Price Item (API Response)

nonisolated struct SpotPriceItem: Codable, Equatable, Sendable {
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

// MARK: - Displayable Error

struct DisplayableError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

extension Error {
    /// Prefer typed Swedish `LocalizedError` descriptions over raw `localizedDescription`.
    var userFacingMessage: String {
        if let localized = self as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return String(localized: "Ett oväntat fel inträffade. Försök igen senare.")
    }
}


// MARK: - Fetch status

nonisolated enum FetchFailure: Error, Equatable, Sendable, LocalizedError {
    case offline
    case timeout
    case server(Int)
    case notFound
    case empty
    case decoding
    case unauthorized
    case missingCredentials
    case unknown

    var errorDescription: String? {
        FetchNotice.price(for: self, staleFrom: nil).title
    }

    static func classify(_ error: Error) -> FetchFailure {
        if let failure = error as? FetchFailure {
            return failure
        }
        if let urlError = error as? URLError {
            return classify(urlError)
        }
        if let providerError = error as? ProviderError {
            return classify(providerError)
        }
        if let consumptionError = error as? ConsumptionError {
            return classify(consumptionError)
        }
        if error is DecodingError {
            return .decoding
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return classify(URLError(_nsError: nsError))
        }
        return .unknown
    }

    static func classify(_ error: URLError) -> FetchFailure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .timeout
        default:
            if error.networkUnavailableReason != nil {
                return .offline
            }
            return .timeout
        }
    }

    static func classify(_ error: ProviderError) -> FetchFailure {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .missingCredentials:
            return .missingCredentials
        case .notFound:
            return .notFound
        case .serverError(let code):
            return .server(code)
        case .decodingError, .invalidResponse:
            return .decoding
        case .invalidURL:
            return .unknown
        case .networkError(let inner):
            return classify(inner)
        }
    }

    static func classify(_ error: ConsumptionError) -> FetchFailure {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .missingCredentials:
            return .missingCredentials
        case .notFound:
            return .notFound
        case .serverError(let code):
            return .server(code)
        case .invalidResponse:
            return .decoding
        case .invalidURL:
            return .unknown
        }
    }
}

nonisolated struct FetchNotice: Equatable, Sendable, Identifiable {
    enum Tone: Equatable, Sendable {
        case info
        case warning
        case error
    }

    enum Kind: Equatable, Sendable {
        case prices
        case consumption
        case tomorrow
        case updated
    }

    let id: String
    let kind: Kind
    let tone: Tone
    let icon: String
    let title: String
    let detail: String?

    var accessibilityText: String {
        if let detail, !detail.isEmpty {
            return "\(title) \(detail)"
        }
        return title
    }

    static func price(for failure: FetchFailure, staleFrom: Date?) -> FetchNotice {
        if let staleFrom {
            return FetchNotice(
                id: "prices-stale",
                kind: .prices,
                tone: .warning,
                icon: "clock.arrow.circlepath",
                title: "Visar sparade priser från \(AppFormatters.relativeStamp(staleFrom)).",
                detail: shortReason(failure, forConsumption: false)
            )
        }

        return FetchNotice(
            id: "prices-error",
            kind: .prices,
            tone: .error,
            icon: icon(for: failure),
            title: priceTitle(failure),
            detail: retryDetail(failure)
        )
    }

    static func consumption(
        for failure: FetchFailure,
        providerName: String?,
        stale: Bool,
        lastMeasurement: Date?
    ) -> FetchNotice {
        if stale {
            var detailParts: [String] = []
            if let reason = shortReason(failure, forConsumption: true) {
                detailParts.append(reason)
            }
            if let lastMeasurement {
                detailParts.append("Senaste mätvärde: \(AppFormatters.relativeStamp(lastMeasurement)).")
            }
            return FetchNotice(
                id: "consumption-stale",
                kind: .consumption,
                tone: .warning,
                icon: "clock.arrow.circlepath",
                title: "Visar sparad förbrukning.",
                detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " ")
            )
        }

        return FetchNotice(
            id: "consumption-error",
            kind: .consumption,
            tone: failure == .missingCredentials ? .info : .error,
            icon: icon(for: failure),
            title: consumptionTitle(failure, providerName: providerName),
            detail: consumptionDetail(failure, lastMeasurement: lastMeasurement)
        )
    }

    static func consumptionLag(lastMeasurement: Date) -> FetchNotice {
        FetchNotice(
            id: "consumption-lag",
            kind: .consumption,
            tone: .info,
            icon: "clock",
            title: "Senaste mätvärde: \(AppFormatters.relativeStamp(lastMeasurement)).",
            detail: nil
        )
    }

    static func consumptionGaps(lastMeasurement: Date?) -> FetchNotice {
        let detail = lastMeasurement.map { "Senaste mätvärde: \(AppFormatters.relativeStamp($0))." }
        return FetchNotice(
            id: "consumption-gaps",
            kind: .consumption,
            tone: .warning,
            icon: "exclamationmark.circle",
            title: "Några timmar saknas i förbrukningen.",
            detail: detail
        )
    }

    static func tomorrowComing(updatedAt: Date?) -> FetchNotice {
        FetchNotice(
            id: "tomorrow-coming",
            kind: .tomorrow,
            tone: .info,
            icon: "clock",
            title: "Morgondagens priser kommer runt 13.",
            detail: updatedAt.map { "Uppdaterad \(AppFormatters.relativeStamp($0))." }
        )
    }

    static func tomorrowMissing(updatedAt: Date?) -> FetchNotice {
        FetchNotice(
            id: "tomorrow-missing",
            kind: .tomorrow,
            tone: .info,
            icon: "clock",
            title: "Morgondagens priser är inte ute än.",
            detail: updatedAt.map { "Uppdaterad \(AppFormatters.relativeStamp($0))." }
        )
    }

    static func tomorrowFailed(failure: FetchFailure, updatedAt: Date?) -> FetchNotice {
        let detail = [shortReason(failure, forConsumption: false), updatedAt.map { "Uppdaterad \(AppFormatters.relativeStamp($0))." }]
            .compactMap { $0 }
            .joined(separator: " ")
        return FetchNotice(
            id: "tomorrow-failed",
            kind: .tomorrow,
            tone: .warning,
            icon: "clock",
            title: "Kunde inte hämta morgondagens priser.",
            detail: detail.isEmpty ? nil : detail
        )
    }

    static func updated(at date: Date) -> FetchNotice {
        FetchNotice(
            id: "updated",
            kind: .updated,
            tone: .info,
            icon: "clock",
            title: "Uppdaterad \(AppFormatters.relativeStamp(date)).",
            detail: nil
        )
    }

    private static func priceTitle(_ failure: FetchFailure) -> String {
        switch failure {
        case .offline:
            return "Ingen nätanslutning."
        case .timeout:
            return "Hämtningen tog för lång tid."
        case .server:
            return "Kunde inte hämta priser just nu."
        case .notFound, .empty:
            return "Inga priser för den här dagen."
        case .decoding:
            return "Kunde inte läsa priserna."
        case .unauthorized, .missingCredentials, .unknown:
            return "Kunde inte hämta priser."
        }
    }

    private static func consumptionTitle(_ failure: FetchFailure, providerName: String?) -> String {
        switch failure {
        case .offline:
            return "Ingen nätanslutning."
        case .timeout:
            return "Hämtningen tog för lång tid."
        case .server:
            return "Kunde inte hämta förbrukningen just nu."
        case .unauthorized:
            if let providerName, !providerName.isEmpty {
                return "Fel inloggning till \(providerName)."
            }
            return "Fel inloggning för förbrukning."
        case .missingCredentials:
            return "Ingen inloggning för förbrukning."
        case .notFound, .empty:
            return "Ingen förbrukning hittades för den här månaden."
        case .decoding:
            return "Kunde inte läsa förbrukningen."
        case .unknown:
            return "Kunde inte hämta förbrukningen."
        }
    }

    private static func retryDetail(_ failure: FetchFailure) -> String? {
        switch failure {
        case .offline:
            return "Försök igen när du är ansluten."
        case .timeout, .server, .decoding, .unknown:
            return "Försök igen om en stund."
        case .notFound, .empty, .unauthorized, .missingCredentials:
            return nil
        }
    }

    private static func consumptionDetail(_ failure: FetchFailure, lastMeasurement: Date?) -> String? {
        switch failure {
        case .unauthorized:
            return "Kontrollera uppgifterna under Inställningar."
        case .missingCredentials:
            return "Lägg till den under Inställningar."
        case .offline:
            return "Försök igen när du är ansluten."
        case .timeout, .server, .decoding, .unknown:
            return "Försök igen om en stund."
        case .notFound, .empty:
            return lastMeasurement.map { "Senaste mätvärde: \(AppFormatters.relativeStamp($0))." }
        }
    }

    private static func shortReason(_ failure: FetchFailure, forConsumption: Bool) -> String? {
        switch failure {
        case .offline:
            return "Ingen nätanslutning."
        case .timeout:
            return "Hämtningen tog för lång tid."
        case .server:
            return forConsumption ? "Kunde inte hämta förbrukningen just nu." : "Kunde inte hämta nya priser just nu."
        case .decoding:
            return forConsumption ? "Kunde inte läsa förbrukningen." : "Kunde inte läsa de nya priserna."
        case .unauthorized, .missingCredentials, .notFound, .empty, .unknown:
            return nil
        }
    }

    private static func icon(for failure: FetchFailure) -> String {
        switch failure {
        case .offline, .timeout:
            return "wifi.slash"
        case .unauthorized, .missingCredentials:
            return "key"
        case .notFound, .empty:
            return "tray"
        case .decoding, .server, .unknown:
            return "exclamationmark.circle"
        }
    }
}

nonisolated enum ConsumptionFreshness {
    static func lastMeasurement(
        quarterly: [QuarterlyConsumption]?,
        values: [ConsumptionValue]?
    ) -> Date? {
        let fromQuarterly = quarterly?.map(\.date).max()
        let fromValues = values?.filter { $0.kWh > 0 }.map(\.date).max()
        return [fromQuarterly, fromValues].compactMap { $0 }.max()
    }

    static func isLagging(lastMeasurement: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastMeasurement) >= 3 * 60 * 60
    }

    static func hasGaps(in quarterly: [QuarterlyConsumption]) -> Bool {
        let dates = quarterly.map(\.date).sorted()
        guard dates.count >= 2 else { return false }

        var missingSlots = 0
        for (previous, next) in zip(dates, dates.dropFirst()) {
            let gap = next.timeIntervalSince(previous)
            if gap > 20 * 60 {
                missingSlots += Int((gap / (15 * 60)).rounded(.down)) - 1
            }
        }
        return missingSlots >= 4
    }

    static func notice(
        failure: FetchFailure?,
        providerName: String?,
        isConfigured: Bool,
        showingCached: Bool,
        quarterly: [QuarterlyConsumption]?,
        values: [ConsumptionValue]?
    ) -> FetchNotice? {
        let lastMeasurement = lastMeasurement(quarterly: quarterly, values: values)

        if let failure {
            if failure == .missingCredentials && !isConfigured {
                return .consumption(
                    for: failure,
                    providerName: providerName,
                    stale: false,
                    lastMeasurement: lastMeasurement
                )
            }
            if failure != .missingCredentials {
                return .consumption(
                    for: failure,
                    providerName: providerName,
                    stale: showingCached,
                    lastMeasurement: lastMeasurement
                )
            }
        }

        if let quarterly, hasGaps(in: quarterly) {
            return .consumptionGaps(lastMeasurement: lastMeasurement)
        }
        if let lastMeasurement, isLagging(lastMeasurement: lastMeasurement) {
            return .consumptionLag(lastMeasurement: lastMeasurement)
        }
        return nil
    }
}
