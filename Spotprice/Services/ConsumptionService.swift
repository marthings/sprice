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

final class ConsumptionService {
    private let session: URLSession
    private let baseURL = "https://api-minasidor.vaggerydsenergi.se"
    private var settings: ConsumptionSettings { ConsumptionSettings.shared }

    init(session: URLSession = .shared) {
        self.session = session
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

    // MARK: - Private Helpers

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
