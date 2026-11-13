//
//  VaggerydProvider.swift
//  Spotprice
//
//  Electricity provider for Vaggeryds Energi
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "VaggerydProvider")

// MARK: - Vaggeryd Provider

struct VaggerydProvider: ElectricityProvider, QuarterlyConsumptionProvider {

    // MARK: - Static Metadata

    static let identifier = "vaggeryd"
    static let displayName = "Vaggeryds Energi"
    static let portalURL: URL? = URL(string: "https://minasidor.vaggerydsenergi.se")

    static let credentialFields: [CredentialField] = [
        CredentialField(
            id: "customerId",
            label: "Kundnummer",
            hint: "Finns på din faktura"
        ),
        CredentialField(
            id: "password",
            label: "Lösenord",
            hint: "De fyra sista siffrorna i ditt personnummer",
            isSecure: true
        ),
        CredentialField(
            id: "accountId",
            label: "Konto-ID",
            hint: "Format: XXXXXXXXX-X (t.ex. 354404037-3)"
        ),
        CredentialField(
            id: "utilityId",
            label: "Anläggnings-ID",
            hint: "18-siffrigt ID (t.ex. 735999252003205654)"
        )
    ]

    static let credentialHelpText: String? = """
        1. Öppna Mina Sidor i Chrome
        2. Logga in och gå till statistik
        3. Öppna DevTools (Cmd+Option+I)
        4. Gå till Network-fliken
        5. Ladda om sidan och klicka på en "1"-request
        6. Under Headers → :path hittar du:
        .../monthly/[Konto-ID]/[Anläggnings-ID]/...
        """

    // MARK: - Instance Properties

    private let credentials: ProviderCredentials
    private let session: URLSession
    private let baseURL = "https://api-minasidor.vaggerydsenergi.se"

    // Convenience accessors
    private var customerId: String { credentials["customerId"] }
    private var password: String { credentials["password"] }
    private var accountId: String { credentials["accountId"] }
    private var utilityId: String { credentials["utilityId"] }
    private var netId: String { credentials["netId"].isEmpty ? "VGD" : credentials["netId"] }
    private var type: String { credentials["type"].isEmpty ? "1" : credentials["type"] }

    // MARK: - Init

    init(credentials: ProviderCredentials, session: URLSession) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: - Protocol Methods

    func testConnection() async throws {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        _ = try await fetchConsumption(year: year, month: month)
    }

    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData {
        let url = try buildConsumptionURL(year: year, month: month)
        let request = try buildRequest(url: url)

        logger.info("Vaggeryd fetching monthly consumption for \(year)/\(month)")

        do {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse {
                logger.info("Vaggeryd monthly consumption status \(http.statusCode), response bytes \(data.count)")
            }

            try validateResponse(response)

            let apiResponse = try decodeResponse(ConsumptionAPIResponse.self, from: data)
            logger.info("Vaggeryd monthly consumption decoded \(apiResponse.consumptionValues.count) values")

            let calendar = Calendar.current

            func findValue(for targetYear: Int, targetMonth: Int) -> ConsumptionValueAPI? {
                apiResponse.consumptionValues.first { value in
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: value.date) else { return false }
                    return calendar.component(.year, from: nextDay) == targetYear &&
                           calendar.component(.month, from: nextDay) == targetMonth
                }
            }

            let currentMonthValue = findValue(for: year, targetMonth: month)
            let totalKWh = currentMonthValue?.consumption ?? 0
            guard let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                throw ProviderError.invalidResponse
            }

            return ConsumptionData(
                totalKWh: totalKWh,
                values: apiResponse.consumptionValues.compactMap { value in
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: value.date) else {
                        return nil
                    }
                    guard calendar.component(.year, from: nextDay) == year,
                          calendar.component(.month, from: nextDay) == month else {
                        return nil
                    }
                    return ConsumptionValue(
                        date: value.date,
                        kWh: value.consumption,
                        price: value.price ?? 0
                    )
                },
                meterName: apiResponse.utility.name,
                meterId: apiResponse.utility.meterid ?? "",
                monthDate: monthDate
            )
        } catch let error as ProviderError {
            throw error
        } catch {
            logger.error("Vaggeryd monthly consumption failed: \(error.localizedDescription, privacy: .public)")
            throw ProviderError.networkError(error)
        }
    }

    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption] {
        let url = try buildDailyConsumptionURL(year: year, month: month)
        let request = try buildRequest(url: url)

        logger.info("Vaggeryd fetching daily consumption for \(year)/\(month)")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            logger.info("Vaggeryd daily consumption status \(http.statusCode), response bytes \(data.count)")
        }

        try validateResponse(response)

        let apiResponse = try decodeResponse(ConsumptionAPIResponse.self, from: data)
        logger.info("Vaggeryd daily consumption decoded \(apiResponse.consumptionValues.count) values")

        return apiResponse.consumptionValues
            .map { DailyConsumption(date: $0.date, kWh: $0.consumption) }
            .filter { $0.kWh > 0 }
            .sorted { $0.date < $1.date }
    }

    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption] {
        let url = try buildHourlyConsumptionURL(startDate: startDate, endDate: endDate)
        let request = try buildRequest(url: url)

        logger.info("Vaggeryd fetching hourly consumption")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            logger.info("Vaggeryd hourly consumption status \(http.statusCode), response bytes \(data.count)")
        }

        try validateResponse(response)

        let apiResponse = try decodeResponse(ConsumptionAPIResponse.self, from: data)
        logger.info("Vaggeryd hourly consumption decoded \(apiResponse.consumptionValues.count) values")

        // Times come without offset: the repeated autumn hour must not collapse into one.
        let dates = ClockChangeTimes.resolvingRepeatedHour(apiResponse.consumptionValues.map(\.date))
        return zip(apiResponse.consumptionValues, dates)
            .map { value, date in HourlyConsumption(date: date, kWh: value.consumption) }
            .filter { $0.kWh > 0 }
            .sorted { $0.date < $1.date }
    }

    func fetchQuarterlyConsumption(startDate: Date, endDate: Date) async throws -> [QuarterlyConsumption] {
        let url = try buildQuarterlyConsumptionURL(startDate: startDate, endDate: endDate)
        let request = try buildRequest(url: url)

        logger.info("Vaggeryd fetching quarterly consumption")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            logger.info("Vaggeryd quarterly consumption status \(http.statusCode), response bytes \(data.count)")
        }

        try validateResponse(response)

        let apiResponse = try decodeResponse(ConsumptionAPIResponse.self, from: data)
        logger.info("Vaggeryd quarterly consumption decoded \(apiResponse.consumptionValues.count) values")

        // Times come without offset: the repeated autumn hour must not collapse into one.
        let dates = ClockChangeTimes.resolvingRepeatedHour(apiResponse.consumptionValues.map(\.date))
        return zip(apiResponse.consumptionValues, dates)
            .map { value, date in QuarterlyConsumption(date: date, kWh: value.consumption) }
            .filter { $0.kWh > 0 }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Private Helpers

    private func buildRequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("https://minasidor.vaggerydsenergi.se", forHTTPHeaderField: "Origin")
        request.setValue("https://minasidor.vaggerydsenergi.se/", forHTTPHeaderField: "Referer")
        return request
    }

    private func buildConsumptionURL(year: Int, month: Int) throws -> URL {
        let startYear = 2024
        let path = "/minasidor/v3/consumption/monthly/\(accountId)/\(utilityId)/\(netId)/\(type)/\(startYear)/\(year)/\(month)/1"

        guard let url = URL(string: baseURL + path) else {
            throw ProviderError.invalidURL
        }

        logger.debug("Built Vaggeryd monthly consumption URL")
        return url
    }

    private func buildDailyConsumptionURL(year: Int, month: Int) throws -> URL {
        let path = "/minasidor/v3/consumption/daily/\(accountId)/\(utilityId)/\(netId)/\(type)/\(year)/\(month)/1"

        guard let url = URL(string: baseURL + path) else {
            throw ProviderError.invalidURL
        }

        logger.debug("Built Vaggeryd daily consumption URL")
        return url
    }

    private func buildHourlyConsumptionURL(startDate: Date, endDate: Date) throws -> URL {
        let startStr = AppFormatters.apiDate(startDate)
        let endStr = AppFormatters.apiDate(endDate)

        let path = "/minasidor/v3/consumption/hourly/\(accountId)/\(utilityId)/\(netId)/\(type)/\(startStr)/\(endStr)/1/1"

        guard let url = URL(string: baseURL + path) else {
            throw ProviderError.invalidURL
        }

        logger.debug("Built Vaggeryd hourly consumption URL")
        return url
    }

    private func buildQuarterlyConsumptionURL(startDate: Date, endDate: Date) throws -> URL {
        let startStr = AppFormatters.apiDateTime(startDate)
        let endStr = AppFormatters.apiDateTime(endDate)

        guard let encodedStart = startStr.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedEnd = endStr.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw ProviderError.invalidURL
        }

        let path = "/minasidor/v3/consumption/quarterly/\(accountId)/\(utilityId)/\(netId)/\(type)/\(encodedStart)/\(encodedEnd)/1/1"

        guard let url = URL(string: baseURL + path) else {
            throw ProviderError.invalidURL
        }

        logger.debug("Built Vaggeryd quarterly consumption URL")
        return url
    }

    private func basicAuthHeader() -> String {
        let credentialsString = "\(customerId):\(password)"
        guard let data = credentialsString.data(using: .utf8) else {
            return ""
        }
        let base64 = data.base64EncodedString()
        return "Basic \(base64)"
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw ProviderError.unauthorized
        case 404:
            throw ProviderError.notFound
        default:
            throw ProviderError.serverError(http.statusCode)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = AppFormatters.vaggerydDateDecoder()
#if DEBUG
        VaggerydResponseKeys.record(data)
#endif

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ProviderError.decodingError(error)
        }
    }
}

#if DEBUG
/// Which fields Vaggeryd sends with each value (names only, never values), to see whether
/// it has a status or quality code. Logged and kept in the app group under
/// `debug_vaggerydValueKeys`.
private enum VaggerydResponseKeys {
    static func record(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = object["consumptionValues"] as? [[String: Any]] else { return }
        let valueKeys = Set(values.flatMap(\.keys)).sorted().joined(separator: ",")
        let topKeys = object.keys.sorted().joined(separator: ",")
        logger.info("Vaggeryd response keys: top \(topKeys, privacy: .public), value \(valueKeys, privacy: .public)")
        let defaults = UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier)
        defaults?.set("top: \(topKeys); value: \(valueKeys)", forKey: "debug_vaggerydValueKeys")

        // Status fields per value, grouped, with the first and last date of each group.
        // No amounts are kept.
        func text(_ value: Any?) -> String {
            switch value {
            case nil, is NSNull: return "-"
            case let value as String: return value
            case let value as NSNumber: return value.stringValue
            default: return "?"
            }
        }
        var groups: [String: (count: Int, first: String, last: String)] = [:]
        for value in values {
            let key = "status=\(text(value["status"])) priceStatus=\(text(value["priceStatus"])) isMdbValue=\(text(value["isMdbValue"])) flow=\(text(value["flow"]))"
            let date = text(value["date"])
            let known = groups[key] ?? (0, date, date)
            groups[key] = (known.count + 1, min(known.first, date), max(known.last, date))
        }
        let summary = groups.keys.sorted().map { key in
            let group = groups[key]!
            return "\(key) n=\(group.count) \(group.first)..\(group.last)"
        }.joined(separator: " | ")
        logger.info("Vaggeryd value status: \(summary, privacy: .public)")
        var calls = defaults?.stringArray(forKey: "debug_vaggerydValueStatus") ?? []
        calls.append("\(Date().formatted(.iso8601)) \(summary)")
        defaults?.set(Array(calls.suffix(12)), forKey: "debug_vaggerydValueStatus")
    }
}
#endif

// MARK: - API Response Models (Private)

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
    let price: Double?
}
