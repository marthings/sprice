//
//  ConsumptionSettings.swift
//  Spotprice
//
//  User-configurable settings for consumption data

import Foundation
import Combine

extension Notification.Name {
    static let consumptionSettingsDidSave = Notification.Name("consumptionSettingsDidSave")
}

final class ConsumptionSettings: ObservableObject {
    static let shared = ConsumptionSettings()

    // MARK: - Shared UserDefaults (App Group)

    private static let defaults = UserDefaults(suiteName: "group.mb.Spotprice") ?? .standard

    // MARK: - Keys

    private enum Keys {
        // Legacy keys (for migration)
        static let customerId = "consumption_customerId"
        static let password = "consumption_password"
        static let utilityId = "consumption_utilityId"
        static let accountId = "consumption_accountId"
        static let netId = "consumption_netId"
        static let type = "consumption_type"

        // New multi-provider keys
        static let selectedProviderId = "consumption_selectedProviderId"
        static let providerCredentials = "consumption_providerCredentials"

        // Shared keys
        static let priceArea = "settings_priceArea"
    }

    // MARK: - Published Properties

    @Published var selectedProviderId: String {
        didSet {
            Self.defaults.set(selectedProviderId, forKey: Keys.selectedProviderId)
            objectWillChange.send()
        }
    }

    @Published var priceArea: String {
        didSet { Self.defaults.set(priceArea, forKey: Keys.priceArea) }
    }

    // MARK: - Legacy Properties (Backward Compatibility)

    /// Legacy customerId - reads from current provider's credentials
    var customerId: String {
        get { getCredentials(for: selectedProviderId)["customerId"] }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["customerId"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Legacy password - reads from current provider's credentials
    var password: String {
        get { getCredentials(for: selectedProviderId)["password"] }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["password"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Legacy utilityId - reads from current provider's credentials
    var utilityId: String {
        get { getCredentials(for: selectedProviderId)["utilityId"] }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["utilityId"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Legacy accountId - reads from current provider's credentials
    var accountId: String {
        get { getCredentials(for: selectedProviderId)["accountId"] }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["accountId"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Legacy netId - reads from current provider's credentials
    var netId: String {
        get {
            let value = getCredentials(for: selectedProviderId)["netId"]
            return value.isEmpty ? "VGD" : value
        }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["netId"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Legacy type - reads from current provider's credentials
    var type: String {
        get {
            let value = getCredentials(for: selectedProviderId)["type"]
            return value.isEmpty ? "1" : value
        }
        set {
            var creds = getCredentials(for: selectedProviderId)
            creds["type"] = newValue
            setCredentials(creds, for: selectedProviderId)
        }
    }

    /// Checks if the current provider has all required credentials
    var isConfigured: Bool {
        guard let metadata = ProviderRegistry.shared.metadata(for: selectedProviderId) else {
            return false
        }
        let creds = getCredentials(for: selectedProviderId)
        return creds.isComplete(for: metadata.credentialFields)
    }

    // MARK: - Credential Storage

    /// In-memory cache of credentials (JSON stored in UserDefaults)
    private var credentialsCache: [String: ProviderCredentials] = [:]

    /// Gets credentials for a specific provider
    func getCredentials(for providerId: String) -> ProviderCredentials {
        // Check cache first
        if let cached = credentialsCache[providerId] {
            return cached
        }

        // Load from UserDefaults
        let allCredentials = loadAllCredentials()
        let creds = allCredentials[providerId] ?? ProviderCredentials()
        credentialsCache[providerId] = creds
        return creds
    }

    /// Sets credentials for a specific provider
    func setCredentials(_ credentials: ProviderCredentials, for providerId: String) {
        credentialsCache[providerId] = credentials

        var allCredentials = loadAllCredentials()
        allCredentials[providerId] = credentials
        saveAllCredentials(allCredentials)

        objectWillChange.send()
    }

    /// Updates a single credential field for the current provider
    func updateCredential(key: String, value: String) {
        var creds = getCredentials(for: selectedProviderId)
        creds[key] = value
        setCredentials(creds, for: selectedProviderId)
    }

    // MARK: - Private Credential Persistence

    private func loadAllCredentials() -> [String: ProviderCredentials] {
        guard let data = Self.defaults.data(forKey: Keys.providerCredentials) else {
            return [:]
        }

        do {
            let decoded = try JSONDecoder().decode([String: ProviderCredentials].self, from: data)
            return decoded
        } catch {
            return [:]
        }
    }

    private func saveAllCredentials(_ credentials: [String: ProviderCredentials]) {
        do {
            let data = try JSONEncoder().encode(credentials)
            Self.defaults.set(data, forKey: Keys.providerCredentials)
        } catch {
            // Silently fail - credentials won't persist
        }
    }

    // MARK: - Init

    private init() {
        // Load current values
        self.selectedProviderId = Self.defaults.string(forKey: Keys.selectedProviderId) ?? "vaggeryd"
        self.priceArea = Self.defaults.string(forKey: Keys.priceArea) ?? "SE3"

        // Migrate legacy credentials if needed
        migrateFromLegacyIfNeeded()
    }

    // MARK: - Migration

    private func migrateFromLegacyIfNeeded() {
        // Check if legacy customerId exists
        guard let legacyCustomerId = Self.defaults.string(forKey: Keys.customerId),
              !legacyCustomerId.isEmpty else {
            return
        }

        // Check if we already have migrated credentials for Vaggeryd
        let existingCreds = getCredentials(for: "vaggeryd")
        guard existingCreds["customerId"].isEmpty else {
            return // Already migrated
        }

        // Migrate legacy credentials to Vaggeryd provider
        var credentials = ProviderCredentials()
        credentials["customerId"] = legacyCustomerId
        credentials["password"] = Self.defaults.string(forKey: Keys.password) ?? ""
        credentials["utilityId"] = Self.defaults.string(forKey: Keys.utilityId) ?? ""
        credentials["accountId"] = Self.defaults.string(forKey: Keys.accountId) ?? ""
        credentials["netId"] = Self.defaults.string(forKey: Keys.netId) ?? "VGD"
        credentials["type"] = Self.defaults.string(forKey: Keys.type) ?? "1"

        setCredentials(credentials, for: "vaggeryd")
        selectedProviderId = "vaggeryd"

        // Note: We don't delete legacy keys to allow rollback if needed
    }

    // MARK: - Reset

    func reset() {
        // Clear credentials for current provider
        setCredentials(ProviderCredentials(), for: selectedProviderId)
        priceArea = "SE3"
    }

    func resetAll() {
        // Clear all provider credentials
        saveAllCredentials([:])
        credentialsCache = [:]
        selectedProviderId = "vaggeryd"
        priceArea = "SE3"
    }
}
