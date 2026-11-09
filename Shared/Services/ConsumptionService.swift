//
//  ConsumptionService.swift
//  Spotprice
//
//  Facade for fetching energy consumption data from the selected provider
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "se.spotprice", category: "ConsumptionService")

// MARK: - Service

struct ConsumptionService: Sendable {
    private let session: URLSession

    nonisolated init(session: URLSession = NetworkSession.shared) {
        self.session = session
    }

    // MARK: - Provider Access

    /// Creates the current provider instance
    private func currentProvider() async throws -> any ElectricityProvider {
        let (isConfigured, providerId, credentials) = await MainActor.run {
            let settings = ConsumptionSettings.shared
            return (settings.isConfigured, settings.selectedProviderId, settings.getCredentials(for: settings.selectedProviderId))
        }
        
        guard isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        guard let provider = ProviderRegistry.shared.createProvider(
            identifier: providerId,
            credentials: credentials,
            session: session
        ) else {
            throw ConsumptionError.missingCredentials
        }

        return provider
    }

    // MARK: - Connection Test

    /// Tests the connection to the current provider's API
    func testConnection() async throws {
        let provider = try await currentProvider()
        do {
            try await provider.testConnection()
        } catch let error as ProviderError {
            throw error.toConsumptionError()
        }
    }

    // MARK: - Fetch Methods

    /// Fetches consumption data for the current month
    func fetchCurrentMonthConsumption() async throws -> ConsumptionData {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        return try await fetchConsumption(year: year, month: month)
    }

    /// Fetches consumption data for a specific month
    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData {
        let provider = try await currentProvider()
        do {
            return try await provider.fetchConsumption(year: year, month: month)
        } catch let error as ProviderError {
            throw error.toConsumptionError()
        }
    }

    /// Fetches daily consumption data for a specific month
    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption] {
        let provider = try await currentProvider()
        do {
            return try await provider.fetchDailyConsumption(year: year, month: month)
        } catch let error as ProviderError {
            throw error.toConsumptionError()
        }
    }

    /// Fetches hourly consumption data for a date range
    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption] {
        let provider = try await currentProvider()
        do {
            return try await provider.fetchHourlyConsumption(startDate: startDate, endDate: endDate)
        } catch let error as ProviderError {
            throw error.toConsumptionError()
        }
    }

    /// Fetches 15-min interval consumption data for a date range (if provider supports it)
    func fetchQuarterlyConsumption(startDate: Date, endDate: Date) async throws -> [QuarterlyConsumption] {
        let provider = try await currentProvider()

        guard let quarterlyProvider = provider as? QuarterlyConsumptionProvider else {
            throw ConsumptionError.notFound
        }

        do {
            return try await quarterlyProvider.fetchQuarterlyConsumption(startDate: startDate, endDate: endDate)
        } catch let error as ProviderError {
            throw error.toConsumptionError()
        }
    }

    // MARK: - Monthly Comparison

    /// Fetches consumption comparison between current and previous month
    func fetchMonthlyComparison(spotPriceService: SpotPriceService) async throws -> MonthlyComparison {
        let isConfigured = await MainActor.run { ConsumptionSettings.shared.isConfigured }
        guard isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Calculate previous month
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else {
            throw ConsumptionError.notFound
        }
        let previousYear = calendar.component(.year, from: previousMonthDate)
        let previousMonth = calendar.component(.month, from: previousMonthDate)

        var currentConsumption = try await consumptionWithDailyValues(
            fetchConsumption(year: currentYear, month: currentMonth),
            year: currentYear,
            month: currentMonth
        )

        var previousConsumption: ConsumptionData?
        do {
            previousConsumption = try await consumptionWithDailyValues(
                fetchConsumption(year: previousYear, month: previousMonth),
                year: previousYear,
                month: previousMonth
            )
        } catch {
            logger.info("No previous month consumption data available: \(error.localizedDescription)")
        }

        let lastMeasured = currentConsumption.values.last(where: { $0.kWh > 0 })?.date
            ?? currentConsumption.values.last?.date
        let throughDay = previousConsumption.flatMap { previous in
            SameDayMonthComparison.throughDay(
                currentMonthStart: currentConsumption.monthDate,
                lastMeasuredInCurrent: lastMeasured,
                previousMonthStart: previous.monthDate,
                now: now,
                calendar: calendar
            )
        }

        if let throughDay {
            currentConsumption = currentConsumption.restricting(toDayOfMonth: throughDay, calendar: calendar)
            previousConsumption = previousConsumption?.restricting(toDayOfMonth: throughDay, calendar: calendar)
        }

        let currentAvgPrice = try await fetchAveragePrice(
            for: currentYear,
            month: currentMonth,
            throughDay: throughDay,
            spotPriceService: spotPriceService
        )
        var previousAvgPrice: Double?
        if previousConsumption != nil {
            do {
                previousAvgPrice = try await fetchAveragePrice(
                    for: previousYear,
                    month: previousMonth,
                    throughDay: throughDay,
                    spotPriceService: spotPriceService
                )
            } catch {
                logger.info("Could not fetch previous month average price: \(error.localizedDescription)")
            }
        }

        return MonthlyComparison(
            current: currentConsumption,
            previous: previousConsumption,
            currentAvgPrice: currentAvgPrice,
            previousAvgPrice: previousAvgPrice
        )
    }

    // MARK: - Power Peaks

    /// Calculates power peaks (effekttoppar) for the current month.
    /// Returns the top 3 hourly peaks (kW) from different weekdays during high-load hours (07–20).
    func calculatePowerPeaks() async throws -> [PowerPeak] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            day: 1
        )) else {
            throw ConsumptionError.notFound
        }

        let hourlyData = try await fetchHourlyConsumption(startDate: monthStart, endDate: now)
        logger.info("Power peaks: Got \(hourlyData.count) hourly entries")
        return powerPeaks(fromHourly: hourlyData, calendar: calendar)
    }

    func powerPeaks(fromQuarterly quarterly: [QuarterlyConsumption], calendar: Calendar = .current) -> [PowerPeak] {
        powerPeaks(fromHourly: Self.hourlyConsumption(from: quarterly, calendar: calendar), calendar: calendar)
    }

    func powerPeaks(fromHourly hourlyData: [HourlyConsumption], calendar: Calendar = .current) -> [PowerPeak] {
        logger.info("Power peaks: Got \(hourlyData.count) hourly entries")

        // Filter to weekdays (Mon–Fri) and high-load hours (07–20)
        let filtered = hourlyData.filter { entry in
            let weekday = calendar.component(.weekday, from: entry.date)
            let hour = calendar.component(.hour, from: entry.date)
            // weekday: 1=Sun, 2=Mon, ..., 6=Fri, 7=Sat
            let isWeekday = weekday >= 2 && weekday <= 6
            let isHighLoad = hour >= 7 && hour <= 19
            return isWeekday && isHighLoad
        }

        logger.info("Power peaks: \(filtered.count) entries after weekday/hour filter")

        // Sort by kWh descending and pick top peaks from different days
        let sorted = filtered.sorted { $0.kWh > $1.kWh }
        var peaks: [PowerPeak] = []
        var usedDays: Set<DateComponents> = []

        for entry in sorted {
            let dayComps = calendar.dateComponents([.year, .month, .day], from: entry.date)
            if !usedDays.contains(dayComps) {
                peaks.append(PowerPeak(date: entry.date, kW: entry.kWh))
                usedDays.insert(dayComps)
                if peaks.count >= 3 { break }
            }
        }

        // Sort by kW descending for display
        let result = peaks.sorted { $0.kW > $1.kW }

        for peak in result {
            logger.info("Power peak: \(AppFormatters.powerPeakLabel(peak.date), privacy: .public) -> \(peak.kW, privacy: .public) kW")
        }
        if !result.isEmpty {
            let avg = result.map(\.kW).reduce(0, +) / Double(result.count)
            logger.info("⚡ Average of \(result.count) peaks: \(String(format: "%.2f", avg)) kW")
        }

        return result
    }

    nonisolated static func hourlyConsumption(
        from quarterly: [QuarterlyConsumption],
        calendar: Calendar = .current
    ) -> [HourlyConsumption] {
        var totals: [Date: Double] = [:]
        totals.reserveCapacity(quarterly.count / 4 + 1)
        for entry in quarterly {
            guard let hourStart = calendar.date(
                from: calendar.dateComponents([.year, .month, .day, .hour], from: entry.date)
            ) else {
                continue
            }
            totals[hourStart, default: 0] += entry.kWh
        }
        return totals.keys.sorted().map { HourlyConsumption(date: $0, kWh: totals[$0] ?? 0) }
    }

    // MARK: - Precise Monthly Cost

    /// Calculates precise monthly cost by matching 15-min consumption against the matching 15-min spot price.
    func calculatePreciseMonthlyCost(spotPriceService: SpotPriceService) async throws -> PreciseMonthlyCost {
        let calendar = Calendar.energyHistory
        let now = Date()
        guard let monthStart = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            day: 1
        )) else {
            throw ConsumptionError.notFound
        }

        let quarterlyData = try await fetchQuarterlyConsumption(startDate: monthStart, endDate: now)
        return try await calculatePreciseMonthlyCost(
            from: quarterlyData,
            spotPriceService: spotPriceService,
            calendar: calendar
        )
    }

    func calculatePreciseMonthlyCost(
        from quarterlyData: [QuarterlyConsumption],
        spotPriceService: SpotPriceService,
        calendar: Calendar = .energyHistory
    ) async throws -> PreciseMonthlyCost {
        logger.info("Precise cost: Got \(quarterlyData.count) quarterly intervals")

        guard !quarterlyData.isEmpty else {
            throw ConsumptionError.notFound
        }

        var daysNeeded: Set<DateComponents> = []
        for entry in quarterlyData {
            daysNeeded.insert(calendar.dateComponents([.year, .month, .day], from: entry.date))
        }

        let spotPriceLookup: [Date: Double] = try await withThrowingTaskGroup(of: [(Date, Double)].self) { group in
            for dayComps in daysNeeded {
                guard let dayDate = calendar.date(from: dayComps) else { continue }
                group.addTask {
                    do {
                        let items = try await spotPriceService.fetchSpotPrices(for: dayDate)
                        return items.map { item in
                            (item.timeStart, item.sekPerKWh * 100.0)
                        }
                    } catch {
                        return []
                    }
                }
            }

            var lookup: [Date: Double] = [:]
            for try await pairs in group {
                for (date, price) in pairs {
                    lookup[date] = price
                }
            }
            return lookup
        }

        logger.info("Precise cost: Built price lookup with \(spotPriceLookup.count) intervals")

        var totalCost = 0.0
        var totalKWh = 0.0
        var matchedIntervals = 0

        for entry in quarterlyData {
            guard let priceOre = SpotPriceMatching.price(
                for: entry.date,
                hoursInPeriod: 0.25,
                lookup: spotPriceLookup,
                calendar: calendar
            ) else {
                continue
            }
            totalCost += entry.kWh * priceOre / 100.0
            totalKWh += entry.kWh
            matchedIntervals += 1
        }

        logger.info("Precise cost: \(String(format: "%.2f", totalCost)) kr from \(matchedIntervals)/\(quarterlyData.count) intervals (\(String(format: "%.1f", totalKWh)) kWh)")

        return PreciseMonthlyCost(
            totalCostKr: totalCost,
            totalKWh: totalKWh,
            matchedIntervals: matchedIntervals,
            totalIntervals: quarterlyData.count
        )
    }

    // MARK: - Private Helpers

    private func consumptionWithDailyValues(
        _ consumption: ConsumptionData,
        year: Int,
        month: Int
    ) async -> ConsumptionData {
        guard consumption.values.isEmpty else { return consumption }
        do {
            let daily = try await fetchDailyConsumption(year: year, month: month)
            guard !daily.isEmpty else { return consumption }
            return ConsumptionData(
                totalKWh: daily.reduce(0) { $0 + $1.kWh },
                values: daily.map { ConsumptionValue(date: $0.date, kWh: $0.kWh, price: 0) },
                meterName: consumption.meterName,
                meterId: consumption.meterId,
                monthDate: consumption.monthDate
            )
        } catch {
            return consumption
        }
    }

    /// Fetches average spot price for a given month (öre/kWh)
    private func fetchAveragePrice(
        for year: Int,
        month: Int,
        throughDay: Int? = nil,
        spotPriceService: SpotPriceService
    ) async throws -> Double {
        let calendar = Calendar.current

        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            throw ConsumptionError.notFound
        }
        let now = Date()

        var endDate: Date
        let isCurrentMonth = calendar.component(.year, from: now) == year && calendar.component(.month, from: now) == month
        if isCurrentMonth {
            endDate = now
        } else {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
                throw ConsumptionError.notFound
            }
            endDate = lastDayOfMonth
        }
        if let throughDay,
           let capped = calendar.date(byAdding: .day, value: throughDay - 1, to: monthStart) {
            let cappedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: capped)) ?? capped
            endDate = min(endDate, cappedEnd.addingTimeInterval(-1))
        }

        // For simplicity, sample a few days to get average
        var allPrices: [Double] = []
        var currentDate = monthStart

        // Sample every 3rd day for efficiency
        while currentDate <= endDate {
            do {
                let items = try await spotPriceService.fetchSpotPrices(for: currentDate)
                let dayPrices = items.map { $0.sekPerKWh * 100.0 } // Convert to öre
                allPrices.append(contentsOf: dayPrices)
            } catch {
                logger.debug("Could not fetch prices for \(currentDate): \(error.localizedDescription)")
            }
            guard let nextSampleDate = calendar.date(byAdding: .day, value: 3, to: currentDate) else {
                break
            }
            currentDate = nextSampleDate
        }

        guard !allPrices.isEmpty else {
            throw ConsumptionError.notFound
        }

        return allPrices.reduce(0, +) / Double(allPrices.count)
    }
}

// MARK: - Errors

enum ConsumptionError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ogiltig URL"
        case .invalidResponse:
            return "Ogiltigt svar från servern"
        case .unauthorized:
            return "Felaktiga inloggningsuppgifter"
        case .notFound:
            return "Ingen data hittades"
        case .serverError(let code):
            return "Serverfel (\(code))"
        case .missingCredentials:
            return "Inloggningsuppgifter saknas"
        }
    }
}

// MARK: - ProviderError Extension

extension ProviderError {
    /// Converts ProviderError to ConsumptionError for backward compatibility
    func toConsumptionError() -> ConsumptionError {
        switch self {
        case .invalidURL:
            return .invalidURL
        case .invalidResponse:
            return .invalidResponse
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .notFound
        case .serverError(let code):
            return .serverError(code)
        case .missingCredentials:
            return .missingCredentials
        case .networkError, .decodingError:
            return .invalidResponse
        }
    }
}
