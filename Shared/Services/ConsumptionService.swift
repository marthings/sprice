//
//  ConsumptionService.swift
//  Spotprice
//
//  Facade for fetching energy consumption data from the selected provider
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "ConsumptionService")

// MARK: - Service

struct ConsumptionService: Sendable {
    private let session: URLSession

    init(session: URLSession = NetworkSession.shared) {
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

    /// Fetches daily consumption data for the current month
    func fetchCurrentMonthDailyConsumption() async throws -> [DailyConsumption] {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        return try await fetchDailyConsumption(year: year, month: month)
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

        // Fetch current month consumption
        let currentConsumption = try await fetchConsumption(year: currentYear, month: currentMonth)

        // Fetch previous month consumption (may fail if no data)
        var previousConsumption: ConsumptionData?
        do {
            previousConsumption = try await fetchConsumption(year: previousYear, month: previousMonth)
        } catch {
            logger.info("No previous month consumption data available: \(error.localizedDescription)")
        }

        // Get average prices for both months
        let currentAvgPrice = try await fetchAveragePrice(for: currentYear, month: currentMonth, spotPriceService: spotPriceService)
        var previousAvgPrice: Double?
        if previousConsumption != nil {
            do {
                previousAvgPrice = try await fetchAveragePrice(for: previousYear, month: previousMonth, spotPriceService: spotPriceService)
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

        // Debug logging
        let df = DateFormatter()
        df.dateFormat = "d MMM HH:mm"
        df.locale = Locale(identifier: "sv_SE")
        df.timeZone = TimeZone(identifier: "Europe/Stockholm")
        for peak in result {
            logger.info("⚡ Peak: \(df.string(from: peak.date)) → \(String(format: "%.2f", peak.kW)) kW")
        }
        if !result.isEmpty {
            let avg = result.map(\.kW).reduce(0, +) / Double(result.count)
            logger.info("⚡ Average of \(result.count) peaks: \(String(format: "%.2f", avg)) kW")
        }

        return result
    }

    // MARK: - Precise Monthly Cost

    /// Calculates precise monthly cost by matching 15-min consumption against hourly spot prices
    func calculatePreciseMonthlyCost(spotPriceService: SpotPriceService) async throws -> PreciseMonthlyCost {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            day: 1
        )) else {
            throw ConsumptionError.notFound
        }

        // Fetch quarterly consumption for the whole month
        let quarterlyData = try await fetchQuarterlyConsumption(startDate: monthStart, endDate: now)
        logger.info("Precise cost: Got \(quarterlyData.count) quarterly intervals")

        guard !quarterlyData.isEmpty else {
            throw ConsumptionError.notFound
        }

        // Determine which days we need spot prices for
        var daysNeeded: Set<DateComponents> = []
        for entry in quarterlyData {
            let comps = calendar.dateComponents([.year, .month, .day], from: entry.date)
            daysNeeded.insert(comps)
        }

        // Fetch spot prices for all needed days in parallel
        let spotPriceLookup: [Date: Double] = try await withThrowingTaskGroup(of: [(Date, Double)].self) { group in
            for dayComps in daysNeeded {
                guard let dayDate = calendar.date(from: dayComps) else { continue }
                group.addTask {
                    do {
                        let items = try await spotPriceService.fetchSpotPrices(for: dayDate)
                        return items.compactMap { item in
                            // Floor to hour start for lookup key
                            guard let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: item.timeStart)) else {
                                return nil
                            }
                            return (hourStart, item.sekPerKWh * 100.0) // öre/kWh
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

        logger.info("Precise cost: Built price lookup with \(spotPriceLookup.count) hours")

        // Match each 15-min interval to its hour's spot price
        var totalCost = 0.0
        var totalKWh = 0.0
        var matchedIntervals = 0

        for entry in quarterlyData {
            guard let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: entry.date)) else {
                continue
            }
            if let priceOre = spotPriceLookup[hourStart] {
                totalCost += entry.kWh * priceOre / 100.0  // öre → kr
                totalKWh += entry.kWh
                matchedIntervals += 1
            }
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

    /// Fetches average spot price for a given month (öre/kWh)
    private func fetchAveragePrice(for year: Int, month: Int, spotPriceService: SpotPriceService) async throws -> Double {
        let calendar = Calendar.current

        // Get all days in the month up to today (or entire month if past)
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            throw ConsumptionError.notFound
        }
        let now = Date()

        // Determine end date: either end of month or today
        var endDate: Date
        let isCurrentMonth = calendar.component(.year, from: now) == year && calendar.component(.month, from: now) == month
        if isCurrentMonth {
            endDate = now
        } else {
            // Get last day of month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
                throw ConsumptionError.notFound
            }
            endDate = lastDayOfMonth
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
