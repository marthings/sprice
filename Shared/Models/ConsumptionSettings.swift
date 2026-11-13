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

    private static let realDefaults = UserDefaults(suiteName: "group.mb.Spotprice") ?? .standard
    /// Throw-away store used while demo mode is on. The real suite above is not written then.
    private static let demoSuiteName = "mb.Spotprice.demo"
    private static let demoDefaults = UserDefaults(suiteName: demoSuiteName) ?? UserDefaults()
    private static var defaults: UserDefaults {
        DemoMode.isActive ? demoDefaults : realDefaults
    }

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
        /// Every saved version of the profile, with the day each applies from (`CostProfileVersion`).
        static let costProfileVersions = "settings_costProfileVersions"

        static let includeHypotheticalEffectTariff = "settings_includeHypotheticalEffectTariff"
        static let compareFixedPriceOrePerKWh = "settings_compareFixedPriceOrePerKWh"
        static let temperaturePlaceId = "settings_temperaturePlaceId"
        static let hasElectricCar = "settings_hasElectricCar"
    }

    // MARK: - Observable Properties

    /// True while invented example data is shown. Mirrors `DemoMode.isActive`, but observable.
    private(set) var isDemoActive = false

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
            saveCostProfileVersion(costProfile)
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
        if DemoMode.isActive { return true }
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

    // MARK: - Rates for today

    /// The effect fee older app versions wrote into the Vaggeryd preset, kr/kW.
    private static let legacyVaggerydPresetPowerFee = 45.0

    /// Brings preset fees and energy tax up to the rows in `HistoricalTariffRates` that apply
    /// today, for example after a new year. Grid fees the user typed in are left alone.
    private static func refreshingRates(
        _ profile: CostProfile,
        cachedTariff: SimplifiedTariff?,
        now: Date = Date()
    ) -> (profile: CostProfile, cachedTariff: SimplifiedTariff?) {
        var next = HistoricalTariffRates.profile(profile, forPeriodStarting: now)
        var nextTariff = cachedTariff

        // Older versions of the app put a 45 kr/kW effect fee in the Vaggeryd preset by
        // mistake. Säkringskunder pay none, so that preset value goes.
        if next.gridCompanyId == "vaggeryd",
           let power = next.effectTariff?.monthlyPricePerKW,
           abs(power - Self.legacyVaggerydPresetPowerFee) < 0.01 {
            next = next.settingEffectTariff(nil)
        }

        // The cached preset tariff follows today's rows too.
        if let tariff = nextTariff,
           let fuse = tariff.fuseSize ?? next.fuseSize,
           let row = HistoricalTariffRates.gridFee(company: tariff.dsoOrgNo, fuseSize: fuse, on: now) {
            let tax = HistoricalTariffRates.energyTax(
                for: EnergyTaxRegion.forGridCompany(tariff.dsoOrgNo),
                on: now
            )
            let isOutdated = abs(tariff.monthlyFixedFee - row.monthlyFee) > 0.01
                || abs(tariff.energyTariffPerKWh * 100.0 - row.transferOrePerKWh) > 0.01
                || (tax.map { abs(tariff.energyTaxPerKWh - $0) > 0.001 } ?? false)
            if isOutdated,
               let fresh = GridTariffService().localPresetTariff(forDSO: tariff.dsoOrgNo, fuseSize: fuse) {
                nextTariff = fresh
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

    // MARK: - Cost Profile Versions

    /// Every saved version of the profile, oldest first. `costProfile` is the one in force today.
    var costProfileVersions: [CostProfileVersion] {
        CostProfileHistory.decoded(Self.defaults.data(forKey: Keys.costProfileVersions))
    }

    /// The profile that applied at `date`. Costs are still priced with `costProfile` for now;
    /// choosing the version per interval comes later.
    func profile(on date: Date) -> CostProfile {
        CostProfileHistory.profile(on: date, in: costProfileVersions) ?? costProfile
    }

    /// The first time versions are used, the saved profile becomes the first version.
    /// Runs on every start and does nothing once versions exist.
    private func migrateCostProfileVersionsIfNeeded() {
        let existing = costProfileVersions
        guard existing.isEmpty else { return }
        let migrated = CostProfileHistory.migrated(existing, currentProfile: costProfile)
        if let data = CostProfileHistory.encoded(migrated) {
            Self.defaults.set(data, forKey: Keys.costProfileVersions)
        }
    }

    /// Saves `profile` as the version from the start of today. Changes only apply forward.
    private func saveCostProfileVersion(_ profile: CostProfile, now: Date = Date()) {
        let existing = costProfileVersions
        let next = CostProfileHistory.saving(profile, on: now, to: existing)
        guard next != existing, let data = CostProfileHistory.encoded(next) else { return }
        Self.defaults.set(data, forKey: Keys.costProfileVersions)
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

        let refreshed = Self.refreshingRates(costProfile, cachedTariff: Self.loadCachedTariff())
        self.costProfile = refreshed.profile
        if let tariff = refreshed.cachedTariff {
            self.cachedTariff = tariff
        }

        saveCostProfile(costProfile)
        migrateCostProfileVersionsIfNeeded()
        saveCostProfileVersion(costProfile)
        mirrorCostProfileToLegacyDefaults(costProfile)
        syncLegacyProperties(from: costProfile)
#if DEBUG
        _ = CostProfileVersionGuard.isValid
        _ = HistoricalTariffRatesGuard.isValid
        _ = HistoryPricingGuard.isValid
        _ = IntervalCoverageGuard.isValid
#endif

        // The real values are loaded and saved above. Demo mode starts after that, so it
        // starts from them and can put them back.
        if DemoMode.preference {
            setDemoMode(true)
        }
    }

    // MARK: - Demo mode

    /// The real in-memory values, kept while demo mode is on.
    private struct RealValues {
        let selectedProviderId: String
        let costProfile: CostProfile
        let hasElectricCar: Bool
        let temperaturePlaceId: String
        let includeHypotheticalEffectTariff: Bool
        let compareFixedPriceOrePerKWh: Double
    }

    @ObservationIgnored private var realValues: RealValues?

    /// Turns example data on or off. Nothing real is written in between: while demo is on,
    /// every setting goes to a throw-away store, and turning it off puts the real values back
    /// and deletes that store. The real saved history, widget cache and credentials are not touched.
    func setDemoMode(_ enabled: Bool) {
        guard enabled != isDemoActive else { return }
        if enabled {
            realValues = RealValues(
                selectedProviderId: selectedProviderId,
                costProfile: costProfile,
                hasElectricCar: hasElectricCar,
                temperaturePlaceId: temperaturePlaceId,
                includeHypotheticalEffectTariff: includeHypotheticalEffectTariff,
                compareFixedPriceOrePerKWh: compareFixedPriceOrePerKWh
            )
            Self.demoDefaults.removePersistentDomain(forName: Self.demoSuiteName)
            DemoMode.setActive(true)
            EnergyHistoryStores.resetDemo()
            selectedProviderId = DemoMode.providerID
            costProfile = DemoMode.costProfile
            hasElectricCar = true
            temperaturePlaceId = "jonkoping"
            includeHypotheticalEffectTariff = false
            compareFixedPriceOrePerKWh = CostUsageInsights.defaultFixedPriceOrePerKWh
        } else if let real = realValues {
            // Still in demo mode here, so these assignments land in the throw-away store.
            selectedProviderId = real.selectedProviderId
            costProfile = real.costProfile
            hasElectricCar = real.hasElectricCar
            temperaturePlaceId = real.temperaturePlaceId
            includeHypotheticalEffectTariff = real.includeHypotheticalEffectTariff
            compareFixedPriceOrePerKWh = real.compareFixedPriceOrePerKWh
            realValues = nil
            DemoMode.setActive(false)
            EnergyHistoryStores.resetDemo()
            Self.demoDefaults.removePersistentDomain(forName: Self.demoSuiteName)
        }
        isDemoActive = enabled
        DemoMode.preference = enabled
        NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
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

    // MARK: - Disconnect

    /// Forgets a data source: removes its login from the Keychain (and the old
    /// copy kept in the settings file for Vaggeryd), clears cached consumption
    /// and stops fetching from it. Saved history is left to the caller.
    func disconnectProvider(_ providerId: String) {
        guard !providerId.isEmpty else { return }

        var all = loadAllCredentials()
        all[providerId] = nil
        if all.isEmpty {
            KeychainHelper.delete(forKey: Self.keychainKey)
        } else {
            saveAllCredentials(all)
        }
        credentialsCache[providerId] = nil
        // Vaggeryd was the only source before several were supported. Its login was
        // kept in plain settings for rollback, and would be migrated back otherwise.
        if providerId == "vaggeryd" {
            for key in [Keys.customerId, Keys.password, Keys.utilityId, Keys.accountId, Keys.netId, Keys.type] {
                Self.defaults.removeObject(forKey: key)
            }
        }

        if selectedProviderId == providerId {
            selectedProviderId = ""
        }
        cachedConsumption = nil
        if costProfile.confidence == .providerConnected {
            costProfile = costProfile.applyingInferredConfidence(
                preservingProviderConnected: false,
                configuredSource: .userEntered
            )
        }
        NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
        WidgetReload.timelines()
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
        // Widgets keep showing real data, so demo mode never asks them to reload.
        guard !DemoMode.isActive else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.iOSApp)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.macOSMenuBar)
    }
}


nonisolated enum EffectTariffCopy {
    nonisolated static let toggleTitle = "Räkna med effektavgift"
    nonisolated static let explanation = "Visar vad toppen hade kostat om elnätet tog betalt för den. Elnätsbolag får i dag inte ta betalt för effekttoppen."
    nonisolated static let lineTitle = "Effektavgift (om den räknades)"
    nonisolated static let missingRate = "Det finns ingen effektavgift i dina elnätsuppgifter, så vi visar bara toppen i kW."
    nonisolated static let dailyBarsNote = "Den syns inte i dygnsstaplarna. Det är en månadsavgift, inte en kostnad per dag."
}

nonisolated enum ElectricCarCopy {
    nonisolated static let toggleTitle = "Jag har elbil"
    nonisolated static let toggleExplanation = "Appen letar efter timmar som ser ut som laddning. Det är en gissning, inte ett faktum."

    nonisolated static let infoParagraphs = [
        "Appen letar efter minst två timmar i rad där du drar tydligt mer än det du alltid drar, ungefär som en laddbox. En enfasladdare drar runt 3,7 kW och en trefasladdare runt 11 kW.",
        "Lasten ska vara ganska jämn, och oftast sker det på kvällen eller natten. Ett kort avbrott på högst en timme räknas in.",
        "Ett högt och jämnt uttag mitt på dagen kan också räknas, eftersom det liknar trefasladdning.",
        "Det är en gissning. En värmepump, bastu eller annat som går länge på jämn last kan se likadant ut."
    ]

}
