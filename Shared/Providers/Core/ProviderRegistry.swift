//
//  ProviderRegistry.swift
//  Spotprice
//
//  Registry for available consumption data sources.
//

import Foundation
import os

// MARK: - Provider Registry

final class ProviderRegistry: @unchecked Sendable {
    static let shared = ProviderRegistry()

    private var providers: [String: any ElectricityProvider.Type] = [:]
    private let lock = NSLock()

    private init() {
        // Register built-in consumption data sources
        register(TibberProvider.self)
        register(VaggerydProvider.self)
    }

    /// Registers a provider type
    func register<P: ElectricityProvider>(_ type: P.Type) {
        lock.lock()
        defer { lock.unlock() }
        providers[type.identifier] = type
    }

    /// Returns metadata for all registered providers
    func allProviderMetadata() -> [ProviderMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return providers.values.map { ProviderMetadata.from($0) }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Returns metadata for a specific provider
    func metadata(for identifier: String) -> ProviderMetadata? {
        lock.lock()
        defer { lock.unlock() }
        guard let type = providers[identifier] else { return nil }
        return ProviderMetadata.from(type)
    }

    /// Creates a provider instance
    func createProvider(
        identifier: String,
        credentials: ProviderCredentials,
        session: URLSession = NetworkSession.shared
    ) -> (any ElectricityProvider)? {
        lock.lock()
        defer { lock.unlock() }
        guard let type = providers[identifier] else { return nil }
        return type.init(credentials: credentials, session: session)
    }

    /// Checks if a provider identifier is valid
    func isValidProvider(_ identifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return providers[identifier] != nil
    }

    /// Returns all provider identifiers
    var allIdentifiers: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.keys).sorted()
    }
}

// MARK: - Demo mode

/// Demo mode ("Visa exempeldata"): invented data for a fictional household, so the app can be
/// tried without an account.
///
/// Why it cannot touch real data:
/// - Settings: while demo is on, `ConsumptionSettings` reads and writes a separate, throw-away
///   UserDefaults suite. The real app group suite is not written. Turning demo off puts the
///   real in-memory values back and deletes the throw-away suite.
/// - History: `EnergyHistoryStores` hands out an in-memory SwiftData container instead of the saved one.
/// - Consumption: `ConsumptionService` uses `DemoProvider`. Real credentials are never read.
/// - Prices and temperature: generated here. The price cache and temperature cache are not used.
/// - Widgets: the widget summary cache, the markers for finished repricing and the widget reload
///   are skipped. Widgets keep showing real data.
/// - The on/off choice itself lives in `UserDefaults.standard`, never in the app group.
nonisolated enum DemoMode {
    static let providerID = "demo"
    static let preferenceKey = "demoMode.enabled"

    private struct State: Sendable {
        var isActive = false
        var epoch = 0
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// True while invented data is shown.
    static var isActive: Bool { state.withLock { $0.isActive } }

    /// Increases every time demo mode is switched. A load that started in one mode drops its
    /// result if the epoch changed, so demo numbers never end up in real storage.
    static var epoch: Int { state.withLock { $0.epoch } }

    static func setActive(_ value: Bool) {
        state.withLock {
            $0.isActive = value
            $0.epoch += 1
        }
    }

    /// What the person chose last time. Read once at launch.
    static var preference: Bool {
        get { UserDefaults.standard.bool(forKey: preferenceKey) }
        set { UserDefaults.standard.set(newValue, forKey: preferenceKey) }
    }

    /// Cost profile of the fictional household: elområde SE3, a retailer with a small markup,
    /// and a grid company with a monthly fee and a transfer fee.
    static var costProfile: CostProfile {
        CostProfile(
            priceArea: "SE3",
            retailContractType: .spotPriceMarkup,
            retailerMarkupOrePerKWh: 6,
            contractPriceOrePerKWh: nil,
            retailerMonthlyFee: 49,
            retailContractSource: .userEntered,
            gridCompanyId: nil,
            gridCompanyName: "Exempelnät",
            fuseSize: 20,
            gridMonthlyFee: 345,
            gridTransferOrePerKWh: 34,
            gridCostSource: .userEntered,
            energyTaxOrePerKWh: CostProfile.SwedishDefaults.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: CostProfile.SwedishDefaults.certificateFeeOrePerKWh,
            vatRate: CostProfile.SwedishDefaults.vatRate,
            effectTariff: nil,
            confidence: .userConfigured,
            source: .userEntered,
            tariffLastUpdated: nil,
            tariffValidUntil: nil
        )
    }
}

/// Invented numbers for a Swedish household in SE3 (about 15 to 20 kWh a day, evening peaks,
/// an electric car charging some nights). Everything is a pure function of the date, so the
/// same day always gives the same numbers, also across month boundaries and clock changes.
nonisolated enum DemoData {
    static let meterName = "Exempelhushåll"
    static let meterId = "DEMO-0001"
    /// Full months of history before the current one.
    static let monthsOfHistory = 13
    /// Quarter-hour values for this many days back, hourly values for older months.
    static let quarterlyDays = 100

    private static let calendar = Calendar.energyHistory
    private static let eurPerSek = 11.2

    // MARK: Noise

    /// Stable number in 0..<1 from a few integers.
    private static func unit(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> Double {
        var x = UInt64(bitPattern: Int64(a)) &* 0x9E37_79B9_7F4A_7C15
        x ^= UInt64(bitPattern: Int64(b)) &* 0xBF58_476D_1CE4_E5B9
        x ^= UInt64(bitPattern: Int64(c)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 30
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x >> 11) / Double(UInt64(1) << 53)
    }

    /// Whole days since 2020-01-01 (Swedish time).
    private static func dayNumber(_ dayStart: Date) -> Int {
        let reference = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 1_577_836_800)
        return Int((dayStart.timeIntervalSince(reference) / 86_400).rounded())
    }

    private static func dayOfYear(_ dayStart: Date) -> Double {
        Double(calendar.ordinality(of: .day, in: .year, for: dayStart) ?? 1)
    }

    // MARK: Temperature

    /// Mean outdoor temperature of one day, in °C.
    static func temperature(onDayStarting dayStart: Date) -> Double {
        let n = dayNumber(dayStart)
        let seasonal = 6.5 + 10.5 * sin(2 * .pi * (dayOfYear(dayStart) - 110) / 365)
        let weather = (0.5 * unit(n, 1) + 0.3 * unit(n - 1, 1) + 0.2 * unit(n - 2, 1) - 0.5) * 12
        return ((seasonal + weather) * 10).rounded() / 10
    }

    static func temperatures(from start: Date, to end: Date) -> [Date: Double] {
        var result: [Date: Double] = [:]
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            result[day] = temperature(onDayStarting: day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: Spot prices

    private static let priceShape: [Double] = [
        0.72, 0.68, 0.65, 0.65, 0.70, 0.85, 1.10, 1.40, 1.45, 1.20, 1.00, 0.90,
        0.85, 0.82, 0.85, 0.95, 1.15, 1.50, 1.65, 1.50, 1.25, 1.00, 0.85, 0.75
    ]

    /// Spot prices for one day, as the real price source gives them (quarter-hours, SEK per kWh without VAT).
    static func priceItems(for date: Date) -> [SpotPriceItem] {
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let n = dayNumber(dayStart)
        let doy = dayOfYear(dayStart)
        let winterness = 0.5 + 0.5 * cos(2 * .pi * (doy - 15) / 365)
        let seasonalOre = 34 + 56 * winterness
        let trend = 0.6 * unit(n, 2) + 0.4 * unit(n - 1, 2)
        var level = seasonalOre * exp(0.9 * (trend - 0.5))
        if winterness > 0.6 && unit(n, 3) > 0.96 {
            level *= 2.2
        }
        let amplitude = 0.55 + 0.45 * winterness

        var items: [SpotPriceItem] = []
        var start = dayStart
        var index = 0
        while start < nextDay {
            let end = start.addingTimeInterval(900)
            let hour = calendar.component(.hour, from: start)
            let shape = 1 + (priceShape[hour] - 1) * amplitude
            let noise = 1 + (unit(n, 4, index) - 0.5) * 0.08
            let ore = max(level * shape * noise, 1)
            items.append(
                SpotPriceItem(
                    sekPerKWh: ore / 100,
                    eurPerKWh: ore / 100 / eurPerSek,
                    exr: eurPerSek,
                    timeStart: start,
                    timeEnd: min(end, nextDay)
                )
            )
            start = end
            index += 1
        }
        return items
    }

    // MARK: Consumption

    /// Share of a typical day's use per hour (kW), before scaling.
    private static let weekdayProfile: [Double] = [
        0.40, 0.40, 0.40, 0.40, 0.40, 0.45, 0.80, 1.10, 0.90, 0.55, 0.55, 0.55,
        0.55, 0.55, 0.55, 0.60, 0.80, 1.40, 1.70, 1.50, 1.20, 0.90, 0.60, 0.45
    ]
    private static let weekendProfile: [Double] = [
        0.40, 0.40, 0.40, 0.40, 0.40, 0.40, 0.45, 0.65, 0.90, 1.00, 1.00, 1.10,
        1.10, 0.95, 0.90, 0.95, 1.10, 1.50, 1.70, 1.50, 1.20, 0.90, 0.60, 0.45
    ]
    private static let baseScale = 0.58
    private static let heatingKWPerDegree = 0.014
    private static let chargerKW = 3.7

    /// A night when the car charges: starts 22:00 or 23:00 and runs two to four hours.
    private static func chargingSession(startingOn dayStart: Date) -> (start: Date, end: Date)? {
        let n = dayNumber(dayStart)
        guard unit(n, 7) < 0.32 else { return nil }
        let startHour = 22 + Int(unit(n, 8) * 2)
        let hours = 2 + Int(unit(n, 9) * 3)
        guard let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: dayStart) else { return nil }
        return (start, start.addingTimeInterval(Double(hours) * 3600))
    }

    /// Quarter-hour use for one day. Always the whole day, so the caller can cut what it needs.
    private static func quarterly(forDayStarting dayStart: Date) -> [QuarterlyConsumption] {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart) else { return [] }
        let n = dayNumber(dayStart)
        let weekday = calendar.component(.weekday, from: dayStart)
        let isWeekend = weekday == 1 || weekday == 7
        let profile = isWeekend ? weekendProfile : weekdayProfile
        let dayFactor = 0.9 + 0.2 * unit(n, 5)
        let heatKW = max(0, 16 - temperature(onDayStarting: dayStart)) * heatingKWPerDegree
        let sessions = [chargingSession(startingOn: previousDay), chargingSession(startingOn: dayStart)].compactMap { $0 }

        var result: [QuarterlyConsumption] = []
        var start = dayStart
        var index = 0
        while start < nextDay {
            let hour = calendar.component(.hour, from: start)
            var kW = (profile[hour] * baseScale + 0.05) * dayFactor
            kW *= 0.85 + 0.3 * unit(n, 6, index)
            kW += heatKW * (hour < 6 ? 0.85 : 1.05)
            var kWh = kW * 0.25
            if (6..<22).contains(hour) && unit(n, 10, index) > 0.97 {
                kWh += 0.3 + 0.3 * unit(n, 11, index)
            }
            if sessions.contains(where: { $0.start <= start && start < $0.end }) {
                kWh += chargerKW * 0.25 * (0.99 + 0.02 * unit(n, 12, index))
            }
            result.append(QuarterlyConsumption(date: start, kWh: (kWh * 1000).rounded() / 1000))
            start = start.addingTimeInterval(900)
            index += 1
        }
        return result
    }

    /// The last moment with a measurement. Real meters report a little late.
    static func measuredThrough(now: Date = Date()) -> Date {
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return hour
    }

    /// First day with data.
    static func firstDay(now: Date = Date()) -> Date {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .month, value: -monthsOfHistory, to: monthStart) ?? monthStart
    }

    static func quarterlyConsumption(from start: Date, to end: Date, now: Date = Date()) -> [QuarterlyConsumption] {
        let limit = min(end, measuredThrough(now: now))
        let first = max(start, firstDay(now: now))
        guard first < limit else { return [] }
        var result: [QuarterlyConsumption] = []
        var day = calendar.startOfDay(for: first)
        while day < limit {
            result += quarterly(forDayStarting: day).filter { $0.date >= first && $0.date < limit }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Quarter-hours only exist for the last `quarterlyDays` days. Older months come as hours.
    static func quarterlyCutoff(now: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -quarterlyDays, to: calendar.startOfDay(for: now)) ?? now
    }

    static func hourlyConsumption(from start: Date, to end: Date, now: Date = Date()) -> [HourlyConsumption] {
        let quarters = quarterlyConsumption(from: start, to: end, now: now)
        var hours: [Date: Double] = [:]
        for quarter in quarters {
            let hourStart = calendar.dateInterval(of: .hour, for: quarter.date)?.start ?? quarter.date
            hours[hourStart, default: 0] += quarter.kWh
        }
        return hours.map { HourlyConsumption(date: $0.key, kWh: $0.value) }.sorted { $0.date < $1.date }
    }

    static func dailyConsumption(year: Int, month: Int, now: Date = Date()) -> [DailyConsumption] {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return [] }
        let quarters = quarterlyConsumption(from: monthStart, to: monthEnd, now: now)
        var days: [Date: Double] = [:]
        for quarter in quarters {
            days[calendar.startOfDay(for: quarter.date), default: 0] += quarter.kWh
        }
        return days.map { DailyConsumption(date: $0.key, kWh: $0.value) }.sorted { $0.date < $1.date }
    }
}

/// The data source used while demo mode is on. It is never listed among the real providers.
nonisolated struct DemoProvider: QuarterlyConsumptionProvider {
    static let identifier = DemoMode.providerID
    static let displayName = "Exempeldata"
    static let portalURL: URL? = nil
    static let credentialFields: [CredentialField] = []
    static let credentialHelpText: String? = nil

    init(credentials: ProviderCredentials, session: URLSession) {}
    init() {}

    func testConnection() async throws {}

    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData {
        let calendar = Calendar.energyHistory
        let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let days = DemoData.dailyConsumption(year: year, month: month)
        return ConsumptionData(
            totalKWh: days.reduce(0) { $0 + $1.kWh },
            values: days.map { ConsumptionValue(date: $0.date, kWh: $0.kWh, price: 0) },
            meterName: DemoData.meterName,
            meterId: DemoData.meterId,
            monthDate: monthDate
        )
    }

    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption] {
        DemoData.dailyConsumption(year: year, month: month)
    }

    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption] {
        DemoData.hourlyConsumption(from: startDate, to: endDate)
    }

    func fetchQuarterlyConsumption(startDate: Date, endDate: Date) async throws -> [QuarterlyConsumption] {
        guard startDate >= DemoData.quarterlyCutoff() else { return [] }
        return DemoData.quarterlyConsumption(from: startDate, to: endDate)
    }
}
