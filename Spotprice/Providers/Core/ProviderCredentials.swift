//
//  ProviderCredentials.swift
//  Spotprice
//
//  Credential field definitions and storage for providers
//

import Foundation

// MARK: - Credential Field

/// Describes a single credential field for a provider
struct CredentialField: Identifiable, Sendable, Equatable {
    /// Storage key (used in UserDefaults)
    let id: String

    /// UI label (e.g., "Kundnummer")
    let label: String

    /// Help text (e.g., "Finns på din faktura")
    let hint: String

    /// Whether to use SecureField
    let isSecure: Bool

    init(id: String, label: String, hint: String, isSecure: Bool = false) {
        self.id = id
        self.label = label
        self.hint = hint
        self.isSecure = isSecure
    }
}

// MARK: - Provider Credentials

/// Container for credential values, keyed by field ID
struct ProviderCredentials: Sendable, Equatable, Codable {
    private var values: [String: String]

    init() {
        self.values = [:]
    }

    init(values: [String: String]) {
        self.values = values
    }

    subscript(key: String) -> String {
        get { values[key] ?? "" }
        set { values[key] = newValue }
    }

    /// Checks if all required fields have non-empty values
    func isComplete(for fields: [CredentialField]) -> Bool {
        fields.allSatisfy { !self[$0.id].isEmpty }
    }

    /// Returns all stored key-value pairs
    var allValues: [String: String] { values }
}
