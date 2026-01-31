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
        didSet { UserDefaults.standard.set(customerId, forKey: Keys.customerId) }
    }
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: Keys.password) }
    }
    @Published var utilityId: String {
        didSet { UserDefaults.standard.set(utilityId, forKey: Keys.utilityId) }
    }
    @Published var accountId: String {
        didSet { UserDefaults.standard.set(accountId, forKey: Keys.accountId) }
    }
    @Published var netId: String {
        didSet { UserDefaults.standard.set(netId, forKey: Keys.netId) }
    }
    @Published var type: String {
        didSet { UserDefaults.standard.set(type, forKey: Keys.type) }
    }

    var isConfigured: Bool {
        !customerId.isEmpty && !password.isEmpty && !utilityId.isEmpty && !accountId.isEmpty
    }

    // MARK: - Init

    private init() {
        self.customerId = UserDefaults.standard.string(forKey: Keys.customerId) ?? ""
        self.password = UserDefaults.standard.string(forKey: Keys.password) ?? ""
        self.utilityId = UserDefaults.standard.string(forKey: Keys.utilityId) ?? ""
        self.accountId = UserDefaults.standard.string(forKey: Keys.accountId) ?? ""
        self.netId = UserDefaults.standard.string(forKey: Keys.netId) ?? "VGD"
        self.type = UserDefaults.standard.string(forKey: Keys.type) ?? "1"
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
