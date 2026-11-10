//
//  ConsumptionSettings.swift
//  Spotprice
//
//  User-configurable settings for consumption data

import Foundation
import WidgetKit

extension Notification.Name {
    static let consumptionSettingsDidSave = Notification.Name("consumptionSettingsDidSave")
    static let energyHistoryDidUpdate = Notification.Name("energyHistoryDidUpdate")
}

@Observable @MainActor
final class ConsumptionSettings {
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
        
        // Grid tariff keys
        static let selectedDSOOrgNo = "settings_selectedDSOOrgNo"
        static let cachedTariff = "settings_cachedTariff"
        
        // Electricity provider cost keys
        static let providerSurcharge = "settings_providerSurcharge"
        static let providerMonthlyFee = "settings_providerMonthlyFee"
        
        // Fuse size (säkring)
        static let fuseSize = "settings_fuseSize"
        
        // Cached consumption data (for widget access)
        static let cachedConsumption = "cached_consumptionData"

        // Central cost profile
        static let costProfile = "settings_costProfile"

        static let includeHypotheticalEffectTariff = "settings_includeHypotheticalEffectTariff"
        static let compareFixedPriceOrePerKWh = "settings_compareFixedPriceOrePerKWh"
        static let temperaturePlaceId = "settings_temperaturePlaceId"
        static let hasElectricCar = "settings_hasElectricCar"
    }

    // MARK: - Observable Properties

    var selectedProviderId: String {
        didSet {
            guard selectedProviderId != oldValue else { return }
            Self.defaults.set(selectedProviderId, forKey: Keys.selectedProviderId)
            // Clear cached consumption when switching providers (different home/meter)
            Self.defaults.removeObject(forKey: Keys.cachedConsumption)
        }
    }

    var priceArea: String {
        didSet {
            guard priceArea != oldValue else { return }
            Self.defaults.set(priceArea, forKey: Keys.priceArea)
        }
    }
    
    var selectedDSOOrgNo: String {
        didSet {
            guard selectedDSOOrgNo != oldValue else { return }
            Self.defaults.set(selectedDSOOrgNo, forKey: Keys.selectedDSOOrgNo)
            // Clear cached tariff when DSO changes
            Self.defaults.removeObject(forKey: Keys.cachedTariff)
        }
    }
    
    // Cached tariff (to avoid frequent API calls)
    var cachedTariff: SimplifiedTariff? {
        get {
            guard let data = Self.defaults.data(forKey: Keys.cachedTariff) else {
                return nil
            }
            return try? JSONDecoder().decode(SimplifiedTariff.self, from: data)
        }
        set {
            guard newValue != cachedTariff else { return }
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue) {
                Self.defaults.set(data, forKey: Keys.cachedTariff)
            } else {
                Self.defaults.removeObject(forKey: Keys.cachedTariff)
            }
        }
    }
    
    // Electricity provider costs
    var providerSurchargePerKWh: Double {
        didSet {
            guard providerSurchargePerKWh != oldValue else { return }
            Self.defaults.set(providerSurchargePerKWh, forKey: Keys.providerSurcharge)
        }
    }
    
    var providerMonthlyFee: Double {
        didSet {
            guard providerMonthlyFee != oldValue else { return }
            Self.defaults.set(providerMonthlyFee, forKey: Keys.providerMonthlyFee)
        }
    }
    
    // Fuse size in amperes (default 20A, common for Swedish homes)
    var fuseSize: Int {
        didSet {
            guard fuseSize != oldValue else { return }
            Self.defaults.set(fuseSize, forKey: Keys.fuseSize)
            // Clear cached tariff when fuse size changes
            Self.defaults.removeObject(forKey: Keys.cachedTariff)
        }
    }

    var costProfile: CostProfile {
        didSet {
            guard costProfile != oldValue else { return }
            saveCostProfile(costProfile)
            mirrorCostProfileToLegacyDefaults(costProfile)
            syncLegacyProperties(from: costProfile)
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)

            Self.defaults.synchronize()
            WidgetReload.timelines()
        }
    }

    /// When false (default), effect tariff is omitted from shown costs.
    /// When true, peak × kr/kW is shown as a hypothetical extra.
    var includeHypotheticalEffectTariff: Bool {
        didSet {
            guard includeHypotheticalEffectTariff != oldValue else { return }
            Self.defaults.set(includeHypotheticalEffectTariff, forKey: Keys.includeHypotheticalEffectTariff)
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
            Self.defaults.synchronize()
            WidgetReload.timelines()
        }
    }

    /// Fixed retail price used only for the "spot versus fixed" comparison, öre/kWh including VAT.
    var compareFixedPriceOrePerKWh: Double {
        didSet {
            guard compareFixedPriceOrePerKWh != oldValue else { return }
            Self.defaults.set(compareFixedPriceOrePerKWh, forKey: Keys.compareFixedPriceOrePerKWh)
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
            Self.defaults.synchronize()
        }
    }

    /// When false (default), the app does not look for charging sessions.
    /// When true, Vad drog? and the day view may show a guess about elbilsladdning.
    var hasElectricCar: Bool {
        didSet {
            guard hasElectricCar != oldValue else { return }
            Self.defaults.set(hasElectricCar, forKey: Keys.hasElectricCar)
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
            Self.defaults.synchronize()
        }
    }

    /// Named place used for outdoor temperature. No GPS; the user picks it in Settings.
    var temperaturePlaceId: String {
        didSet {
            guard temperaturePlaceId != oldValue else { return }
            Self.defaults.set(temperaturePlaceId, forKey: Keys.temperaturePlaceId)
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
            Self.defaults.synchronize()
        }
    }

    var temperaturePlace: TemperaturePlace {
        TemperaturePlace.place(id: temperaturePlaceId)
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

    /// Effective surcharge: user value if set, otherwise provider default
    var effectiveSurchargePerKWh: Double {
        let defaults = ProviderDefaults.forProvider(selectedProviderId)
        return providerSurchargePerKWh > 0 ? providerSurchargePerKWh : (defaults.surchargePerKWh ?? 0)
    }

    /// Effective monthly fee: user value if set, otherwise provider default
    var effectiveMonthlyFee: Double {
        let defaults = ProviderDefaults.forProvider(selectedProviderId)
        return providerMonthlyFee > 0 ? providerMonthlyFee : (defaults.monthlyFee ?? 0)
    }

    /// Checks if the current provider has all required credentials
    var isConfigured: Bool {
        guard let metadata = ProviderRegistry.shared.metadata(for: selectedProviderId) else {
            return false
        }
        let creds = getCredentials(for: selectedProviderId)
        return creds.isComplete(for: metadata.credentialFields)
    }
    
    // MARK: - Cached Consumption (for widget access)
    
    /// Cached consumption data (stored in shared UserDefaults for widget access)
    var cachedConsumption: ConsumptionData? {
        get {
            guard let data = Self.defaults.data(forKey: Keys.cachedConsumption) else {
                return nil
            }
            return try? JSONDecoder().decode(ConsumptionData.self, from: data)
        }
        set {
            guard newValue != cachedConsumption else { return }
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue) {
                Self.defaults.set(data, forKey: Keys.cachedConsumption)
            } else {
                Self.defaults.removeObject(forKey: Keys.cachedConsumption)
            }
            WidgetReload.timelines()
        }
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
        guard getCredentials(for: providerId) != credentials else { return }
        credentialsCache[providerId] = credentials

        var allCredentials = loadAllCredentials()
        allCredentials[providerId] = credentials
        saveAllCredentials(allCredentials)
    }

    /// Updates a single credential field for the current provider
    func updateCredential(key: String, value: String) {
        var creds = getCredentials(for: selectedProviderId)
        creds[key] = value
        setCredentials(creds, for: selectedProviderId)
    }

    // MARK: - Private Credential Persistence

    private static let keychainKey = "spotprice.providerCredentials"

    private func loadAllCredentials() -> [String: ProviderCredentials] {
        // Try Keychain first
        if let data = KeychainHelper.load(forKey: Self.keychainKey) {
            if let decoded = try? JSONDecoder().decode([String: ProviderCredentials].self, from: data) {
                return decoded
            }
        }

        // Migrate from UserDefaults if Keychain is empty
        if let data = Self.defaults.data(forKey: Keys.providerCredentials),
           let decoded = try? JSONDecoder().decode([String: ProviderCredentials].self, from: data) {
            // Save to Keychain and remove from UserDefaults
            if let migrated = try? JSONEncoder().encode(decoded) {
                KeychainHelper.save(migrated, forKey: Self.keychainKey)
            }
            Self.defaults.removeObject(forKey: Keys.providerCredentials)
            return decoded
        }

        return [:]
    }

    private func saveAllCredentials(_ credentials: [String: ProviderCredentials]) {
        do {
            let data = try JSONEncoder().encode(credentials)
            KeychainHelper.save(data, forKey: Self.keychainKey)
        } catch {
            // Silently fail - credentials won't persist
        }
    }

    // MARK: - 2026 rate refresh

    /// Old 2025 energy tax stored including VAT. Exact match only, so a custom value is left alone.
    private static let legacyEnergyTax2025InclVAT = 54.875
    private static let legacyVaggerydMonthlyFees: [Int: Double] = [
        16: 187.50, 20: 225.00, 25: 270.00, 35: 360.00, 50: 495.00, 63: 612.50
    ]
    private static let legacyVaggerydTransferOrePerKWh = 28.13
    private static let legacyVaggerydPowerTariff = 45.00

    private static func refreshing2026Rates(
        _ profile: CostProfile,
        cachedTariff: SimplifiedTariff?
    ) -> (profile: CostProfile, cachedTariff: SimplifiedTariff?) {
        var next = profile
        var nextTariff = cachedTariff

        if abs(next.energyTaxOrePerKWh - legacyEnergyTax2025InclVAT) < 0.001 {
            next = next.updating(energyTaxOrePerKWh: CostProfile.SwedishDefaults.energyTaxOrePerKWh)
        }

        if (next.gridCompanyId ?? "") == "vaggeryd" {
            let fuse = next.fuseSize ?? 20
            let hasLegacyFee = next.gridMonthlyFee.map { fee in
                legacyVaggerydMonthlyFees.values.contains { abs($0 - fee) < 0.01 }
            } ?? false
            let hasLegacyTransfer = next.gridTransferOrePerKWh.map {
                abs($0 - legacyVaggerydTransferOrePerKWh) < 0.01
            } ?? false
            if hasLegacyFee || hasLegacyTransfer {
                let fees: [Int: Double] = [16: 458, 20: 742, 25: 975, 35: 1_233, 50: 1_967, 63: 2_475]
                next = next.updating(
                    gridMonthlyFee: fees[fuse] ?? 742,
                    gridTransferOrePerKWh: 29.75,
                    energyTaxOrePerKWh: CostProfile.SwedishDefaults.energyTaxOrePerKWh
                )
            }
            if let power = next.effectTariff?.monthlyPricePerKW,
               abs(power - legacyVaggerydPowerTariff) < 0.01 {
                next = next.settingEffectTariff(nil)
            }
        }

        if var tariff = nextTariff, tariff.dsoOrgNo == "vaggeryd" {
            let hasLegacyFee = legacyVaggerydMonthlyFees.values.contains {
                abs($0 - tariff.monthlyFixedFee) < 0.01
            }
            let hasLegacyTransfer = abs(tariff.energyTariffPerKWh - 0.2813) < 0.0001
            if hasLegacyFee || hasLegacyTransfer || abs((tariff.energyTaxPerKWh) - legacyEnergyTax2025InclVAT) < 0.001 {
                if let fresh = GridTariffService().localPresetTariff(forDSO: "vaggeryd", fuseSize: tariff.fuseSize ?? next.fuseSize ?? 20) {
                    nextTariff = fresh
                }
            }
        }

        return (next, nextTariff)
    }

    // MARK: - Cost Profile Persistence

    private static func loadCostProfile() -> CostProfile? {
        guard let data = defaults.data(forKey: Keys.costProfile) else {
            return nil
        }
        return (try? JSONDecoder().decode(CostProfile.self, from: data))?.normalizedGridCostSource()
    }

    private func saveCostProfile(_ profile: CostProfile) {
        guard let data = try? JSONEncoder().encode(profile) else {
            return
        }
        Self.defaults.set(data, forKey: Keys.costProfile)
    }

    private func mirrorCostProfileToLegacyDefaults(_ profile: CostProfile) {
        Self.defaults.set(profile.priceArea, forKey: Keys.priceArea)
        Self.defaults.set(profile.retailerMarkupOrePerKWh, forKey: Keys.providerSurcharge)
        Self.defaults.set(profile.retailerMonthlyFee, forKey: Keys.providerMonthlyFee)
        Self.defaults.set(profile.gridCompanyId ?? "", forKey: Keys.selectedDSOOrgNo)
        if let fuseSize = profile.fuseSize {
            Self.defaults.set(fuseSize, forKey: Keys.fuseSize)
        }
    }

    private func syncLegacyProperties(from profile: CostProfile) {
        if priceArea != profile.priceArea {
            priceArea = profile.priceArea
        }
        if providerSurchargePerKWh != profile.retailerMarkupOrePerKWh {
            providerSurchargePerKWh = profile.retailerMarkupOrePerKWh
        }
        if providerMonthlyFee != profile.retailerMonthlyFee {
            providerMonthlyFee = profile.retailerMonthlyFee
        }
        let profileGridCompanyId = profile.gridCompanyId ?? ""
        if selectedDSOOrgNo != profileGridCompanyId {
            selectedDSOOrgNo = profileGridCompanyId
        }
        if let profileFuseSize = profile.fuseSize, fuseSize != profileFuseSize {
            fuseSize = profileFuseSize
        }
    }

    private static func loadCachedTariff() -> SimplifiedTariff? {
        guard let data = defaults.data(forKey: Keys.cachedTariff) else {
            return nil
        }
        return try? JSONDecoder().decode(SimplifiedTariff.self, from: data)
    }

    private static func migratedCostProfile(
        priceArea: String,
        providerSurchargePerKWh: Double,
        providerMonthlyFee: Double,
        selectedDSOOrgNo: String,
        fuseSize: Int,
        cachedTariff: SimplifiedTariff?
    ) -> CostProfile {
        let fallback = CostProfile.swedishDefaultEstimate(priceArea: priceArea)
        let hasUserRetailerValues = providerSurchargePerKWh > 0 || providerMonthlyFee > 0
        let hasGridValues = cachedTariff != nil || !selectedDSOOrgNo.isEmpty

        let confidence: CostConfidence = (hasUserRetailerValues || hasGridValues) ? .userConfigured : .estimated
        let source: TariffSource = hasGridValues ? .localPreset : (hasUserRetailerValues ? .userEntered : .defaultEstimate)

        return CostProfile(
            priceArea: priceArea,
            retailContractType: .spotPriceMarkup,
            retailerMarkupOrePerKWh: hasUserRetailerValues ? providerSurchargePerKWh : fallback.retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: nil,
            retailerMonthlyFee: hasUserRetailerValues ? providerMonthlyFee : fallback.retailerMonthlyFee,
            retailContractSource: hasUserRetailerValues ? .userEntered : .defaultEstimate,
            gridCompanyId: selectedDSOOrgNo.isEmpty ? cachedTariff?.dsoOrgNo : selectedDSOOrgNo,
            gridCompanyName: cachedTariff?.dsoName,
            fuseSize: fuseSize,
            gridMonthlyFee: cachedTariff?.monthlyFixedFee,
            gridTransferOrePerKWh: cachedTariff.map { $0.energyTariffPerKWh * 100.0 },
            gridCostSource: cachedTariff == nil ? nil : .localPreset,
            energyTaxOrePerKWh: cachedTariff?.energyTaxPerKWh ?? fallback.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: cachedTariff?.certificateFeePerKWh ?? fallback.certificateFeeOrePerKWh,
            vatRate: fallback.vatRate,
            effectTariff: cachedTariff?.powerTariffPerKW.map {
                EffectTariff(
                    monthlyPricePerKW: $0,
                    model: .manual,
                    activeHours: .custom
                )
            },
            confidence: confidence,
            source: source,
            tariffLastUpdated: cachedTariff.map { _ in Date() },
            tariffValidUntil: cachedTariff?.validTo
        )
    }

    // MARK: - Init

    private init() {
        // Load current values
        // Default to empty string (no provider) instead of forcing vaggeryd
        let initialSelectedProviderId = Self.defaults.string(forKey: Keys.selectedProviderId) ?? ""
        let initialPriceArea = Self.defaults.string(forKey: Keys.priceArea) ?? "SE3"
        let initialSelectedDSOOrgNo = Self.defaults.string(forKey: Keys.selectedDSOOrgNo) ?? ""
        self.selectedProviderId = initialSelectedProviderId
        self.priceArea = initialPriceArea
        self.selectedDSOOrgNo = initialSelectedDSOOrgNo
        
        // Load provider cost settings (default to 0 - user must configure)
        let initialProviderSurchargePerKWh = Self.defaults.double(forKey: Keys.providerSurcharge)
        let initialProviderMonthlyFee = Self.defaults.double(forKey: Keys.providerMonthlyFee)
        self.providerSurchargePerKWh = initialProviderSurchargePerKWh
        self.providerMonthlyFee = initialProviderMonthlyFee
        
        // Load fuse size (default 20A - common for Swedish homes)
        let savedFuseSize = Self.defaults.integer(forKey: Keys.fuseSize)
        self.fuseSize = savedFuseSize > 0 ? savedFuseSize : 20
        self.includeHypotheticalEffectTariff = Self.defaults.bool(forKey: Keys.includeHypotheticalEffectTariff)
        self.hasElectricCar = Self.defaults.bool(forKey: Keys.hasElectricCar)
        if Self.defaults.object(forKey: Keys.compareFixedPriceOrePerKWh) == nil {
            self.compareFixedPriceOrePerKWh = CostUsageInsights.defaultFixedPriceOrePerKWh
        } else {
            self.compareFixedPriceOrePerKWh = Self.defaults.double(forKey: Keys.compareFixedPriceOrePerKWh)
        }
        if let savedPlace = Self.defaults.string(forKey: Keys.temperaturePlaceId), !savedPlace.isEmpty {
            self.temperaturePlaceId = savedPlace
        } else {
            self.temperaturePlaceId = TemperaturePlace.defaultID(forDSO: initialSelectedDSOOrgNo)
        }

        // Load or migrate central cost profile
        self.costProfile = Self.loadCostProfile() ?? Self.migratedCostProfile(
            priceArea: initialPriceArea,
            providerSurchargePerKWh: initialProviderSurchargePerKWh,
            providerMonthlyFee: initialProviderMonthlyFee,
            selectedDSOOrgNo: initialSelectedDSOOrgNo,
            fuseSize: savedFuseSize > 0 ? savedFuseSize : 20,
            cachedTariff: Self.loadCachedTariff()
        )

        // Migrate legacy credentials if needed
        migrateFromLegacyIfNeeded()

        let refreshed = Self.refreshing2026Rates(costProfile, cachedTariff: Self.loadCachedTariff())
        self.costProfile = refreshed.profile
        if let tariff = refreshed.cachedTariff {
            self.cachedTariff = tariff
        }

        saveCostProfile(costProfile)
        mirrorCostProfileToLegacyDefaults(costProfile)
        syncLegacyProperties(from: costProfile)
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
        // Clear all provider credentials from Keychain and cache
        KeychainHelper.delete(forKey: Self.keychainKey)
        credentialsCache = [:]
        selectedProviderId = ""
        priceArea = "SE3"
    }
}

// MARK: - Form Bindings

enum SettingsBind: Hashable {
    case priceArea
    case retailContractType
    case retailerMarkupOre
    case contractPriceOre
    case retailerMonthlyFee
    case gridMonthlyFee
    case gridTransferOre
    case effectTariffEnabled
    case effectTariffPrice
}

extension ConsumptionSettings {
    subscript(credential field: String, provider providerId: String) -> String {
        get { getCredentials(for: providerId)[field] }
        set {
            var credentials = getCredentials(for: providerId)
            guard credentials[field] != newValue else { return }
            credentials[field] = newValue
            setCredentials(credentials, for: providerId)
        }
    }

    subscript(priceArea _: SettingsBind) -> String {
        get { costProfile.priceArea }
        set {
            costProfile = costProfile.updating(priceArea: newValue)
        }
    }

    subscript(retailContractType _: SettingsBind) -> RetailContractType {
        get { costProfile.retailContractType }
        set { setRetailContractType(newValue) }
    }

    subscript(retailerMarkupOre _: SettingsBind) -> Double {
        get { costProfile.retailerMarkupOrePerKWh }
        set { setRetailerMarkupOre(newValue) }
    }

    subscript(contractPriceOre _: SettingsBind) -> Double {
        get { costProfile.contractPriceOrePerKWh ?? 0 }
        set { setContractPriceOre(newValue) }
    }

    subscript(retailerMonthlyFee _: SettingsBind) -> Double {
        get { costProfile.retailerMonthlyFee }
        set { setRetailerMonthlyFee(newValue) }
    }

    subscript(gridMonthlyFee _: SettingsBind) -> Double {
        get { costProfile.gridMonthlyFee ?? 0 }
        set {
            setManualGridCosts(
                monthlyFee: newValue,
                transferFee: costProfile.gridTransferOrePerKWh ?? 0
            )
        }
    }

    subscript(gridTransferOre _: SettingsBind) -> Double {
        get { costProfile.gridTransferOrePerKWh ?? 0 }
        set {
            setManualGridCosts(
                monthlyFee: costProfile.gridMonthlyFee ?? 0,
                transferFee: newValue
            )
        }
    }

    subscript(effectTariffEnabled _: SettingsBind) -> Bool {
        get { costProfile.effectTariff != nil }
        set {
            if newValue {
                setEffectTariffPrice(costProfile.effectTariff?.monthlyPricePerKW ?? 0)
            } else {
                costProfile = costProfile
                    .settingEffectTariff(nil)
                    .applyingInferredConfidence()
            }
        }
    }

    subscript(effectTariffPrice _: SettingsBind) -> Double {
        get { costProfile.effectTariff?.monthlyPricePerKW ?? 0 }
        set { setEffectTariffPrice(newValue) }
    }

    func setRetailContractType(_ type: RetailContractType) {
        let contractPrice = type == .spotPriceMarkup ? nil : costProfile.contractPriceOrePerKWh
        costProfile = costProfile.settingRetailContract(
            type: type,
            contractPriceOrePerKWh: contractPrice,
            retailContractSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
    }

    func setRetailerMarkupOre(_ markup: Double) {
        costProfile = costProfile.settingRetailContract(
            type: .spotPriceMarkup,
            retailerMarkupOrePerKWh: markup,
            contractPriceOrePerKWh: nil,
            retailContractSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
    }

    func setContractPriceOre(_ price: Double) {
        costProfile = costProfile.settingRetailContract(
            type: costProfile.retailContractType,
            contractPriceOrePerKWh: price,
            retailContractSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
    }

    func setRetailerMonthlyFee(_ monthlyFee: Double) {
        costProfile = costProfile.settingRetailContract(
            type: costProfile.retailContractType,
            contractPriceOrePerKWh: costProfile.contractPriceOrePerKWh,
            retailerMonthlyFee: monthlyFee,
            retailContractSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
    }

    func resetRetailContractToDefaults() {
        costProfile = costProfile
            .settingRetailContract(
                type: .spotPriceMarkup,
                retailerMarkupOrePerKWh: CostProfile.SwedishDefaults.retailerMarkupOrePerKWh,
                contractPriceOrePerKWh: nil,
                retailerMonthlyFee: CostProfile.SwedishDefaults.retailerMonthlyFee,
                retailContractSource: .defaultEstimate
            )
            .applyingInferredConfidence(configuredSource: .userEntered)
    }

    func setManualGridCosts(monthlyFee: Double, transferFee: Double, gridCompanyName: String? = nil) {
        costProfile = costProfile.updating(
            gridCompanyId: selectedDSOOrgNo.isEmpty ? costProfile.gridCompanyId : selectedDSOOrgNo,
            gridCompanyName: gridCompanyName ?? costProfile.gridCompanyName,
            fuseSize: fuseSize,
            gridMonthlyFee: monthlyFee,
            gridTransferOrePerKWh: transferFee,
            gridCostSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
    }

    func setEffectTariffPrice(_ monthlyPricePerKW: Double) {
        costProfile = costProfile.settingEffectTariff(
            EffectTariff(
                monthlyPricePerKW: monthlyPricePerKW,
                model: .manual,
                activeHours: .custom
            ),
            confidence: .userConfigured,
            source: .userEntered
        )
    }
}

enum WidgetKind {
    static let iOSApp = "SpotpriceAppWidgetV2"
    static let macOSMenuBar = "SpotpriceWidget"
}

enum WidgetReload {
    static func timelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.iOSApp)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.macOSMenuBar)
    }
}


nonisolated enum EffectTariffCopy {
    nonisolated static let toggleTitle = "Räkna med effektavgift"
    nonisolated static let explanation = "Visar vad toppen hade kostat om elnätet tog betalt för den. Elnätsbolag får i dag inte ta betalt för effekttoppen."
    nonisolated static let lineTitle = "Effektavgift (om den räknades)"
    nonisolated static let missingRate = "Ingen effektavgift i dina elnätsuppgifter, så toppen visas bara som hur mycket el som gick åt just då (kW)."
    nonisolated static let dailyBarsNote = "Den syns inte i dygnsstaplarna. Det är en månadsavgift, inte en kostnad per dag."
}

nonisolated enum ElectricCarCopy {
    nonisolated static let toggleTitle = "Jag har elbil"
    nonisolated static let toggleExplanation = "När det är på letar appen efter timmar som ser ut som laddning. Det är en gissning, inte ett faktum."

    nonisolated static let infoParagraphs = [
        "Appen letar efter minst två timmar i rad där du drar tydligt mer än det du alltid drar. Det ska motsvara en vanlig laddbox. En enfasladdare drar ungefär 3,7 kW och en trefasladdare ungefär 11 kW. kW är hur mycket el som går åt just då, och går 1 kW åt i en timme blir det 1 kWh.",
        "Lasten ska vara ganska jämn, och det sker oftast på kvällen eller natten. Ett kort avbrott på högst en timme räknas in i samma tillfälle.",
        "Ett tydligt, jämnt och högt uttag mitt på dagen kan också räknas med, eftersom det liknar trefasladdning.",
        "Det är en gissning. En värmepump, en bastu eller något annat som går länge på jämn last kan se likadant ut."
    ]

}
