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
        static let customerId = "consumption_customerId"
        static let password = "consumption_password"
        static let utilityId = "consumption_utilityId"
        static let accountId = "consumption_accountId"
        static let netId = "consumption_netId"
        static let type = "consumption_type"
    }

    // MARK: - Properties

    @Published var customerId: String {
        didSet { Self.defaults.set(customerId, forKey: Keys.customerId) }
    }
    @Published var password: String {
        didSet { Self.defaults.set(password, forKey: Keys.password) }
    }
    @Published var utilityId: String {
        didSet { Self.defaults.set(utilityId, forKey: Keys.utilityId) }
    }
    @Published var accountId: String {
        didSet { Self.defaults.set(accountId, forKey: Keys.accountId) }
    }
    @Published var netId: String {
        didSet { Self.defaults.set(netId, forKey: Keys.netId) }
    }
    @Published var type: String {
        didSet { Self.defaults.set(type, forKey: Keys.type) }
    }

    var isConfigured: Bool {
        !customerId.isEmpty && !password.isEmpty && !utilityId.isEmpty && !accountId.isEmpty
    }

    // MARK: - Init

    private init() {
        self.customerId = Self.defaults.string(forKey: Keys.customerId) ?? ""
        self.password = Self.defaults.string(forKey: Keys.password) ?? ""
        self.utilityId = Self.defaults.string(forKey: Keys.utilityId) ?? ""
        self.accountId = Self.defaults.string(forKey: Keys.accountId) ?? ""
        self.netId = Self.defaults.string(forKey: Keys.netId) ?? "VGD"
        self.type = Self.defaults.string(forKey: Keys.type) ?? "1"
    }

    func reset() {
        customerId = ""
        password = ""
        utilityId = ""
        accountId = ""
        netId = "VGD"
        type = "1"
    }
}
