//
//  TibberProvider.swift
//  Spotprice
//
//  Electricity provider for Tibber
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "TibberProvider")

struct TibberProvider: ElectricityProvider {

    // MARK: - Static Metadata

    static let identifier = "tibber"
    static let displayName = "Tibber"
    static let portalURL: URL? = URL(string: "https://developer.tibber.com/")

    static let credentialFields: [CredentialField] = [
        CredentialField(
            id: "accessToken",
            label: "Access Token",
            hint: "Hämtas från developer.tibber.com",
            isSecure: true
        )
    ]

    static let credentialHelpText: String? = """
        1. Gå till developer.tibber.com
        2. Logga in med ditt Tibber-konto
        3. Kopiera din Access Token
        """

    // MARK: - Instance Properties

    private let credentials: ProviderCredentials
    private let session: URLSession
    private let graphQLEndpoint = URL(string: "https://api.tibber.com/v1-beta/gql")!

    private var accessToken: String { credentials["accessToken"] }

    // MARK: - Init

    init(credentials: ProviderCredentials, session: URLSession) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: - Protocol Methods

    func testConnection() async throws {
        // Test by fetching homes
        let query = """
        {
            viewer {
                homes {
                    id
                    address {
                        address1
                    }
                }
            }
        }
        """

        let response: TibberViewerResponse = try await executeQuery(query)
        guard !response.data.viewer.homes.isEmpty else {
            throw ProviderError.notFound
        }
        logger.info("Tibber: Found \(response.data.viewer.homes.count) home(s)")
    }

    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData {
        let homeId = try await getFirstHomeId()
        let calendar = Calendar.current
        let now = Date()
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let monthDate = targetDate

        // Check if this is the current month (not yet closed)
        let isCurrentMonth = calendar.component(.year, from: now) == year &&
                             calendar.component(.month, from: now) == month

        if isCurrentMonth {
            // For current month, sum up daily data instead
            logger.info("Tibber: Current month - using daily data")
            let dailyData = try await fetchDailyConsumption(year: year, month: month)
            let totalKWh = dailyData.reduce(0) { $0 + $1.kWh }

            // Also fetch cost from hourly data if available
            let address = try await fetchHomeAddress(homeId: homeId)

            logger.info("Tibber: Current month total from daily: \(totalKWh) kWh")

            return ConsumptionData(
                totalKWh: totalKWh,
                values: dailyData.map { ConsumptionValue(date: $0.date, kWh: $0.kWh, price: 0) },
                meterName: address,
                meterId: homeId,
                monthDate: monthDate
            )
        }

        // For past months, use monthly resolution
        let monthsBack = calendar.dateComponents([.month], from: targetDate, to: now).month ?? 0

        let query = """
        {
            viewer {
                home(id: "\(homeId)") {
                    consumption(resolution: MONTHLY, last: \(max(monthsBack + 1, 12))) {
                        nodes {
                            from
                            to
                            cost
                            unitPrice
                            consumption
                        }
                    }
                    address {
                        address1
                    }
                }
            }
        }
        """

        let response: TibberHomeResponse = try await executeQuery(query)

        guard let home = response.data.viewer.home else {
            logger.error("Tibber: No home found in response")
            throw ProviderError.notFound
        }

        logger.info("Tibber: Got \(home.consumption.nodes.count) monthly nodes")

        // Find the node matching our target month
        let targetNode = home.consumption.nodes.first { node in
            guard let fromDate = node.fromDate else { return false }
            let nodeYear = calendar.component(.year, from: fromDate)
            let nodeMonth = calendar.component(.month, from: fromDate)
            return nodeYear == year && nodeMonth == month
        }

        let totalKWh = targetNode?.consumption ?? 0
        let totalCost = targetNode?.cost ?? 0
        logger.info("Tibber: Month \(year)-\(month) = \(totalKWh) kWh, \(totalCost) kr")

        return ConsumptionData(
            totalKWh: totalKWh,
            values: home.consumption.nodes.compactMap { node in
                guard let date = node.fromDate else { return nil }
                return ConsumptionValue(
                    date: date,
                    kWh: node.consumption ?? 0,
                    price: node.cost ?? 0
                )
            },
            meterName: home.address?.address1 ?? "Tibber",
            meterId: homeId,
            monthDate: monthDate
        )
    }

    private func fetchHomeAddress(homeId: String) async throws -> String {
        let query = """
        {
            viewer {
                home(id: "\(homeId)") {
                    address {
                        address1
                    }
                }
            }
        }
        """

        struct AddressResponse: Decodable {
            let data: DataContainer
            struct DataContainer: Decodable {
                let viewer: ViewerContainer
            }
            struct ViewerContainer: Decodable {
                let home: HomeContainer?
            }
            struct HomeContainer: Decodable {
                let address: AddressContainer?
            }
            struct AddressContainer: Decodable {
                let address1: String?
            }
        }

        let response: AddressResponse = try await executeQuery(query)
        return response.data.viewer.home?.address?.address1 ?? "Tibber"
    }

    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption] {
        let homeId = try await getFirstHomeId()
        let calendar = Calendar.current

        // Calculate days in month and how far back
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let now = Date()
        let daysBack = calendar.dateComponents([.day], from: targetDate, to: now).day ?? 0

        // Get enough days to cover the target month
        let daysInMonth = calendar.range(of: .day, in: .month, for: targetDate)?.count ?? 31

        let query = """
        {
            viewer {
                home(id: "\(homeId)") {
                    consumption(resolution: DAILY, last: \(max(daysBack + daysInMonth, 60))) {
                        nodes {
                            from
                            to
                            consumption
                        }
                    }
                }
            }
        }
        """

        let response: TibberHomeResponse = try await executeQuery(query)

        guard let home = response.data.viewer.home else {
            throw ProviderError.notFound
        }

        // Filter to only the requested month
        return home.consumption.nodes.compactMap { node in
            guard let date = node.fromDate,
                  calendar.component(.year, from: date) == year,
                  calendar.component(.month, from: date) == month,
                  let consumption = node.consumption else {
                return nil
            }
            return DailyConsumption(date: date, kWh: consumption)
        }.sorted { $0.date < $1.date }
    }

    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption] {
        let homeId = try await getFirstHomeId()
        let calendar = Calendar.current

        // Calculate hours between now and start
        let now = Date()
        let hoursBack = calendar.dateComponents([.hour], from: startDate, to: now).hour ?? 0

        // Add buffer for the range
        let hoursInRange = calendar.dateComponents([.hour], from: startDate, to: endDate).hour ?? 24

        let query = """
        {
            viewer {
                home(id: "\(homeId)") {
                    consumption(resolution: HOURLY, last: \(max(hoursBack + hoursInRange, 168))) {
                        nodes {
                            from
                            to
                            consumption
                        }
                    }
                }
            }
        }
        """

        let response: TibberHomeResponse = try await executeQuery(query)

        guard let home = response.data.viewer.home else {
            throw ProviderError.notFound
        }

        // Filter to the requested range
        return home.consumption.nodes.compactMap { node in
            guard let date = node.fromDate,
                  date >= startDate && date <= endDate,
                  let consumption = node.consumption else {
                return nil
            }
            return HourlyConsumption(date: date, kWh: consumption)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Private Helpers

    private func getFirstHomeId() async throws -> String {
        let query = """
        {
            viewer {
                homes {
                    id
                }
            }
        }
        """

        let response: TibberViewerResponse = try await executeQuery(query)
        guard let firstHome = response.data.viewer.homes.first else {
            throw ProviderError.notFound
        }
        return firstHome.id
    }

    private func executeQuery<T: Decodable>(_ query: String) async throws -> T {
        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = TibberGraphQLRequest(query: query)
        request.httpBody = try JSONEncoder().encode(body)

        logger.debug("Tibber query: \(query)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        logger.info("Tibber HTTP Status: \(http.statusCode)")

        // Always log raw response for debugging
        if let responseStr = String(data: data, encoding: .utf8) {
            logger.info("Tibber raw response: \(responseStr)")
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw ProviderError.unauthorized
        case 404:
            throw ProviderError.notFound
        default:
            throw ProviderError.serverError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Tibber decode error: \(error)")
            throw ProviderError.decodingError(error)
        }
    }
}

// MARK: - Tibber GraphQL Models (Private)

private struct TibberGraphQLRequest: Encodable {
    let query: String
}

// Response for viewer query (list homes)
private struct TibberViewerResponse: Decodable {
    let data: TibberViewerData

    struct TibberViewerData: Decodable {
        let viewer: TibberViewer
    }

    struct TibberViewer: Decodable {
        let homes: [TibberHomeBasic]
    }

    struct TibberHomeBasic: Decodable {
        let id: String
        let address: TibberAddress?
    }

    struct TibberAddress: Decodable {
        let address1: String?
    }
}

// Response for home consumption query
private struct TibberHomeResponse: Decodable {
    let data: TibberHomeData

    struct TibberHomeData: Decodable {
        let viewer: TibberViewerHome
    }

    struct TibberViewerHome: Decodable {
        let home: TibberHome?
    }

    struct TibberHome: Decodable {
        let consumption: TibberConsumption
        let address: TibberAddress?
    }

    struct TibberConsumption: Decodable {
        let nodes: [TibberConsumptionNode]
    }

    struct TibberConsumptionNode: Decodable {
        let from: String
        let to: String
        let cost: Double?
        let unitPrice: Double?
        let consumption: Double?

        /// Parse Tibber's date format: "2026-01-26T04:00:00.000+01:00"
        var fromDate: Date? {
            TibberDateParser.parse(from)
        }
    }

    struct TibberAddress: Decodable {
        let address1: String?
    }
}

// MARK: - Tibber Date Parser

private enum TibberDateParser {
    /// Tibber format: "2026-01-26T04:00:00.000+01:00"
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fallback without fractional seconds
    private static let fallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        if let date = formatter.date(from: string) {
            return date
        }
        return fallbackFormatter.date(from: string)
    }
}
