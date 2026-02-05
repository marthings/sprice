//
//  ConsumptionService.swift
//  Spotprice
//
//  Fetches energy consumption data from Vaggeryds Energi API
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "ConsumptionService")

// MARK: - Service

struct ConsumptionService: Sendable {
    private let session: URLSession
    private let baseURL = "https://api-minasidor.vaggerydsenergi.se"
    private var settings: ConsumptionSettings { ConsumptionSettings.shared }

    init(session: URLSession = NetworkSession.shared) {
        self.session = session
    }

    /// Tests the connection to Vaggeryds Energi API
    func testConnection() async throws {
        guard settings.isConfigured else {
            throw ConsumptionError.missingCredentials
        }
        // Försök hämta data för att verifiera credentials
        _ = try await fetchCurrentMonthConsumption()
    }

    /// Fetches consumption data for the current month
    func fetchCurrentMonthConsumption() async throws -> ConsumptionData {
        guard settings.isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        return try await fetchConsumption(year: year, month: month)
    }

    /// Fetches daily consumption data for the current month
    func fetchCurrentMonthDailyConsumption() async throws -> [DailyConsumption] {
        guard settings.isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        return try await fetchDailyConsumption(year: year, month: month)
    }

    /// Fetches consumption comparison between current and previous month
    func fetchMonthlyComparison(spotPriceService: SpotPriceService) async throws -> MonthlyComparison {
        guard settings.isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Calculate previous month
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
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

    /// Fetches average spot price for a given month (öre/kWh)
    private func fetchAveragePrice(for year: Int, month: Int, spotPriceService: SpotPriceService) async throws -> Double {
        let calendar = Calendar.current

        // Get all days in the month up to today (or entire month if past)
        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let now = Date()

        // Determine end date: either end of month or today
        var endDate: Date
        let isCurrentMonth = calendar.component(.year, from: now) == year && calendar.component(.month, from: now) == month
        if isCurrentMonth {
            endDate = now
        } else {
            // Get last day of month
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            endDate = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
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
            currentDate = calendar.date(byAdding: .day, value: 3, to: currentDate)!
        }

        guard !allPrices.isEmpty else {
            throw ConsumptionError.notFound
        }

        return allPrices.reduce(0, +) / Double(allPrices.count)
    }

    /// Fetches daily consumption data for a specific month
    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption] {
        let url = try buildDailyConsumptionURL(year: year, month: month)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("https://minasidor.vaggerydsenergi.se", forHTTPHeaderField: "Origin")
        request.setValue("https://minasidor.vaggerydsenergi.se/", forHTTPHeaderField: "Referer")

        logger.info("Fetching daily consumption for \(year)/\(month)...")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            logger.info("Daily HTTP Status: \(http.statusCode)")
        }

        try validateResponse(response)

        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        let apiResponse = try decoder.decode(ConsumptionAPIResponse.self, from: data)
        logger.info("Daily: Got \(apiResponse.consumptionValues.count) values")

        // Convert to DailyConsumption, filtering out zero values
        return apiResponse.consumptionValues
            .map { DailyConsumption(date: $0.date, kWh: $0.consumption) }
            .filter { $0.kWh > 0 }
            .sorted { $0.date < $1.date }
    }

    /// Fetches consumption data for a specific month
    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData {
        let url = try buildConsumptionURL(year: year, month: month)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("https://minasidor.vaggerydsenergi.se", forHTTPHeaderField: "Origin")
        request.setValue("https://minasidor.vaggerydsenergi.se/", forHTTPHeaderField: "Referer")

        logger.info("Fetching consumption for \(year)/\(month)...")

        do {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse {
                logger.info("HTTP Status: \(http.statusCode)")
                if http.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "nil"
                    logger.error("Response body: \(body)")
                }
            }

            try validateResponse(response)

            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            let apiResponse = try decoder.decode(ConsumptionAPIResponse.self, from: data)
            logger.info("Success! Got \(apiResponse.consumptionValues.count) values")

            // Debug: Log all values
            for value in apiResponse.consumptionValues {
                logger.info("📊 Value: \(value.date) -> \(value.consumption) kWh")
            }

            // Filter to only the requested month
            // Note: API returns dates at end of PREVIOUS month, so 2025-12-31 = January 2026 data
            let calendar = Calendar.current

            func findValue(for targetYear: Int, targetMonth: Int) -> ConsumptionValueAPI? {
                apiResponse.consumptionValues.first { value in
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: value.date) else { return false }
                    return calendar.component(.year, from: nextDay) == targetYear &&
                           calendar.component(.month, from: nextDay) == targetMonth
                }
            }

            // Find value for requested month
            let currentMonthValue = findValue(for: year, targetMonth: month)

            logger.info("📊 Looking for year=\(year), month=\(month)")
            logger.info("📊 Found value: \(currentMonthValue?.consumption ?? 0) kWh")

            let totalKWh = currentMonthValue?.consumption ?? 0
            let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))!

            return ConsumptionData(
                totalKWh: totalKWh,
                values: apiResponse.consumptionValues.map { value in
                    ConsumptionValue(
                        date: value.date,
                        kWh: value.consumption,
                        price: value.price ?? 0
                    )
                },
                meterName: apiResponse.utility.name,
                meterId: apiResponse.utility.meterid ?? "",
                monthDate: monthDate
            )
        } catch {
            logger.error("Error: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetches 15-min interval consumption data for a date range
    func fetchQuarterlyConsumption(startDate: Date, endDate: Date) async throws -> [QuarterlyConsumption] {
        guard settings.isConfigured else {
            throw ConsumptionError.missingCredentials
        }

        let url = try buildQuarterlyConsumptionURL(startDate: startDate, endDate: endDate)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("https://minasidor.vaggerydsenergi.se", forHTTPHeaderField: "Origin")
        request.setValue("https://minasidor.vaggerydsenergi.se/", forHTTPHeaderField: "Referer")

        logger.info("Fetching quarterly consumption...")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            logger.info("Quarterly HTTP Status: \(http.statusCode)")
        }

        try validateResponse(response)

        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        let apiResponse = try decoder.decode(ConsumptionAPIResponse.self, from: data)
        logger.info("Quarterly: Got \(apiResponse.consumptionValues.count) values")

        return apiResponse.consumptionValues
            .map { QuarterlyConsumption(date: $0.date, kWh: $0.consumption) }
            .filter { $0.kWh > 0 }
            .sorted { $0.date < $1.date }
    }

    /// Calculates precise monthly cost by matching 15-min consumption against hourly spot prices
    func calculatePreciseMonthlyCost(spotPriceService: SpotPriceService) async throws -> PreciseMonthlyCost {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            day: 1
        ))!

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
                        return items.map { item in
                            // Floor to hour start for lookup key
                            let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: item.timeStart))!
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
            let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: entry.date))!
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

    private func buildQuarterlyConsumptionURL(startDate: Date, endDate: Date) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Stockholm")

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        guard let encodedStart = startStr.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedEnd = endStr.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw ConsumptionError.invalidURL
        }

        let path = "/minasidor/v3/consumption/quarterly/\(settings.accountId)/\(settings.utilityId)/\(settings.netId)/\(settings.type)/\(encodedStart)/\(encodedEnd)/1/1"

        guard let url = URL(string: baseURL + path) else {
            throw ConsumptionError.invalidURL
        }

        logger.debug("Quarterly URL: \(url.absoluteString)")
        return url
    }

    private func buildConsumptionURL(year: Int, month: Int) throws -> URL {
        // URL pattern: /minasidor/v3/consumption/monthly/{accountId}/{utilityId}/{netId}/{type}/{startYear}/{endYear}/{month}/1
        // Note: startYear seems to be a fixed value (2024), endYear is the query year
        let startYear = 2024
        let path = "/minasidor/v3/consumption/monthly/\(settings.accountId)/\(settings.utilityId)/\(settings.netId)/\(settings.type)/\(startYear)/\(year)/\(month)/1"

        guard let url = URL(string: baseURL + path) else {
            throw ConsumptionError.invalidURL
        }

        logger.debug("URL: \(url.absoluteString)")
        return url
    }

    private func buildDailyConsumptionURL(year: Int, month: Int) throws -> URL {
        // URL pattern: /minasidor/v3/consumption/daily/{accountId}/{utilityId}/{netId}/{type}/{year}/{month}/1
        let path = "/minasidor/v3/consumption/daily/\(settings.accountId)/\(settings.utilityId)/\(settings.netId)/\(settings.type)/\(year)/\(month)/1"

        guard let url = URL(string: baseURL + path) else {
            throw ConsumptionError.invalidURL
        }

        logger.debug("Daily URL: \(url.absoluteString)")
        return url
    }

    private func basicAuthHeader() -> String {
        let credentials = "\(settings.customerId):\(settings.password)"
        guard let data = credentials.data(using: .utf8) else {
            return ""
        }
        let base64 = data.base64EncodedString()
        return "Basic \(base64)"
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ConsumptionError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw ConsumptionError.unauthorized
        case 404:
            throw ConsumptionError.notFound
        default:
            throw ConsumptionError.serverError(http.statusCode)
        }
    }
}

// MARK: - API Response Models

private struct ConsumptionAPIResponse: Decodable {
    let utility: UtilityInfo
    let consumptionValues: [ConsumptionValueAPI]
}

private struct UtilityInfo: Decodable {
    let utilityId: String
    let name: String
    let meterid: String?
    let netId: String
    let type: String
    let active: Bool
    let isHourlyMeasured: Bool
}

private struct ConsumptionValueAPI: Decodable {
    let date: Date
    let consumption: Double
    let price: Double?  // Can be null
}

// MARK: - Public Models

struct ConsumptionData {
    let totalKWh: Double
    let values: [ConsumptionValue]
    let meterName: String
    let meterId: String
    let monthDate: Date

    /// Formatted total for display (e.g., "142 kWh")
    var formattedTotal: String {
        "\(Int(totalKWh.rounded())) kWh"
    }

    /// Month name for display (e.g., "januari 2026")
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }
}

struct ConsumptionValue {
    let date: Date
    let kWh: Double
    let price: Double
}

struct QuarterlyConsumption: Identifiable {
    let date: Date
    let kWh: Double
    var id: Date { date }
}

struct PreciseMonthlyCost {
    let totalCostKr: Double
    let totalKWh: Double
    let matchedIntervals: Int
    let totalIntervals: Int
}

struct DailyConsumption: Identifiable {
    let date: Date
    let kWh: Double

    var id: Date { date }

    /// Day of month for display (e.g., "15 jan")
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

/// Comparison data for current and previous month
struct MonthlyComparison {
    let current: ConsumptionData
    let previous: ConsumptionData?
    let currentAvgPrice: Double  // öre/kWh
    let previousAvgPrice: Double?

    /// Price change percentage (positive = more expensive, negative = cheaper)
    var priceChangePercent: Double? {
        guard let prevPrice = previousAvgPrice, prevPrice > 0 else { return nil }
        return ((currentAvgPrice - prevPrice) / prevPrice) * 100
    }

    /// Current month name (e.g., "februari")
    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: current.monthDate)
    }

    /// Previous month name (e.g., "januari")
    var previousMonthName: String? {
        guard let prev = previous else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: prev.monthDate)
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
