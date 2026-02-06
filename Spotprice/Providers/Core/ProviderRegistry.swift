//
//  ProviderRegistry.swift
//  Spotprice
//
//  Registry for available electricity providers
//

import Foundation

// MARK: - Provider Registry

final class ProviderRegistry: @unchecked Sendable {
    static let shared = ProviderRegistry()

    private var providers: [String: any ElectricityProvider.Type] = [:]
    private let lock = NSLock()

    private init() {
        // Register built-in providers
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
