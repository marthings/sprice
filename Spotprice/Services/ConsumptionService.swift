//
//  ConsumptionService.swift
//  Spotprice
//
//  Fetches energy consumption data from Vaggeryds Energi API
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "ConsumptionService")

// MARK: - Configuration (Replace with your credentials)

enum ConsumptionConfig {
    static let customerId = "113125"
    static let password = "1979"
    static let utilityId = "735999252003205654"  // Fixed: was missing a digit
    static let accountId = "354404037-3"
    static let netId = "VGD"
    static let type = "1"
}

// MARK: - Service

final class ConsumptionService {
    private let session: URLSession
    private let baseURL = "https://api-minasidor.vaggerydsenergi.se"

    init(session: URLSession = .shared) {
        self.session = session
    }

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

            // Filter to only the requested month
            let calendar = Calendar.current
            let currentMonthValue = apiResponse.consumptionValues.first { value in
                calendar.component(.year, from: value.date) == year &&
                calendar.component(.month, from: value.date) == month
            }

            let totalKWh = currentMonthValue?.consumption ?? 0

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
                meterId: apiResponse.utility.meterid ?? ""
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
        let path = "/minasidor/v3/consumption/monthly/\(ConsumptionConfig.accountId)/\(ConsumptionConfig.utilityId)/\(ConsumptionConfig.netId)/\(ConsumptionConfig.type)/\(startYear)/\(year)/\(month)/1"

        guard let url = URL(string: baseURL + path) else {
            throw ConsumptionError.invalidURL
        }

        logger.debug("URL: \(url.absoluteString)")
        return url
    }

    private func basicAuthHeader() -> String {
        let credentials = "\(ConsumptionConfig.customerId):\(ConsumptionConfig.password)"
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

    /// Formatted total for display (e.g., "142 kWh")
    var formattedTotal: String {
        "\(Int(totalKWh.rounded())) kWh"
    }
}

struct ConsumptionValue {
    let date: Date
    let kWh: Double
    let price: Double
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
