//
//  ElectricityProvider.swift
//  Spotprice
//
//  Core protocol for consumption data sources.
//

import Foundation

// MARK: - Provider Protocol

protocol ElectricityProvider: Sendable {
    /// Unique identifier for this provider (e.g., "vaggeryd")
    static var identifier: String { get }

    /// Display name for UI (e.g., "Vaggeryds Energi")
    static var displayName: String { get }

    /// URL to the provider's customer portal (optional)
    static var portalURL: URL? { get }

    /// Credential fields required by this provider
    static var credentialFields: [CredentialField] { get }

    /// Help text explaining how to find credentials (optional)
    static var credentialHelpText: String? { get }

    /// Creates a provider instance with credentials and session
    init(credentials: ProviderCredentials, session: URLSession)

    /// Tests the connection to verify credentials work
    func testConnection() async throws

    /// Fetches monthly consumption summary
    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData

    /// Fetches daily consumption for a month
    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption]

    /// Fetches hourly consumption for a date range
    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption]
}

// MARK: - Optional Capability Protocols

/// Providers that support 15-minute interval data
protocol QuarterlyConsumptionProvider: ElectricityProvider {
    func fetchQuarterlyConsumption(startDate: Date, endDate: Date) async throws -> [QuarterlyConsumption]
}

/// Providers that can supply detailed price information
protocol PriceInfoProvider: ElectricityProvider {
    /// Fetches current price information including all cost components
    func fetchCurrentPriceInfo() async throws -> ProviderCostInfo
    
    /// Fetches today's hourly prices (if supported)
    func fetchTodaysPrices() async throws -> DailyProviderPrices?
    
    /// Provider-specific default values (fallback when API unavailable)
    static var defaultCostInfo: ProviderCostInfo { get }
}

// MARK: - Provider Error

enum ProviderError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case missingCredentials
    case networkError(Error)
    case decodingError(Error)

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
        case .networkError:
            return "Nätverksfel. Kontrollera din anslutning."
        case .decodingError:
            return "Kunde inte läsa svar från servern."
        }
    }
}

// MARK: - Provider Metadata

/// Lightweight struct for listing providers without instantiation
struct ProviderMetadata: Identifiable, Sendable {
    let identifier: String
    let displayName: String
    let portalURL: URL?
    let credentialFields: [CredentialField]
    let credentialHelpText: String?

    var id: String { identifier }

    static func from<P: ElectricityProvider>(_ type: P.Type) -> ProviderMetadata {
        ProviderMetadata(
            identifier: type.identifier,
            displayName: type.displayName,
            portalURL: type.portalURL,
            credentialFields: type.credentialFields,
            credentialHelpText: type.credentialHelpText
        )
    }
}
