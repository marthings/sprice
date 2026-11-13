//
//  CostProfile.swift
//  Spotprice
//
//  Central user-facing cost profile for estimated and configured electricity costs.
//

import Foundation
import os

// MARK: - Cost Profile

nonisolated struct CostProfile: Codable, Equatable, Sendable {
    let priceArea: String
    let retailContractType: RetailContractType
    let retailerMarkupOrePerKWh: Double
    let contractPriceOrePerKWh: Double?
    let retailerMonthlyFee: Double
    let retailContractSource: TariffSource?
    let gridCompanyId: String?
    let gridCompanyName: String?
    let fuseSize: Int?
    let gridMonthlyFee: Double?
    let gridTransferOrePerKWh: Double?
    let gridCostSource: TariffSource?
    let energyTaxOrePerKWh: Double
    let certificateFeeOrePerKWh: Double
    let vatRate: Double
    let effectTariff: EffectTariff?
    let confidence: CostConfidence
    let source: TariffSource
    let tariffLastUpdated: Date?
    let tariffValidUntil: Date?

    init(
        priceArea: String,
        retailContractType: RetailContractType,
        retailerMarkupOrePerKWh: Double,
        contractPriceOrePerKWh: Double?,
        retailerMonthlyFee: Double,
        retailContractSource: TariffSource?,
        gridCompanyId: String?,
        gridCompanyName: String?,
        fuseSize: Int?,
        gridMonthlyFee: Double?,
        gridTransferOrePerKWh: Double?,
        gridCostSource: TariffSource?,
        energyTaxOrePerKWh: Double,
        certificateFeeOrePerKWh: Double,
        vatRate: Double,
        effectTariff: EffectTariff?,
        confidence: CostConfidence,
        source: TariffSource,
        tariffLastUpdated: Date?,
        tariffValidUntil: Date?
    ) {
        self.priceArea = priceArea
        self.retailContractType = retailContractType
        self.retailerMarkupOrePerKWh = retailerMarkupOrePerKWh
        self.contractPriceOrePerKWh = contractPriceOrePerKWh
        self.retailerMonthlyFee = retailerMonthlyFee
        self.retailContractSource = retailContractSource
        self.gridCompanyId = gridCompanyId
        self.gridCompanyName = gridCompanyName
        self.fuseSize = fuseSize
        self.gridMonthlyFee = gridMonthlyFee
        self.gridTransferOrePerKWh = gridTransferOrePerKWh
        self.gridCostSource = gridCostSource
        self.energyTaxOrePerKWh = energyTaxOrePerKWh
        self.certificateFeeOrePerKWh = certificateFeeOrePerKWh
        self.vatRate = vatRate
        self.effectTariff = effectTariff
        self.confidence = confidence
        self.source = source
        self.tariffLastUpdated = tariffLastUpdated
        self.tariffValidUntil = tariffValidUntil
    }

    init?(historySnapshot snapshot: HistoricalCostProfileSnapshot) {
        guard let retailContractType = RetailContractType(rawValue: snapshot.retailContractType) else {
            return nil
        }
        self.init(
            priceArea: snapshot.priceArea,
            retailContractType: retailContractType,
            retailerMarkupOrePerKWh: snapshot.retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: snapshot.contractPriceOrePerKWh,
            retailerMonthlyFee: snapshot.retailerMonthlyFee,
            retailContractSource: snapshot.retailContractSource.flatMap(TariffSource.init(rawValue:)),
            gridCompanyId: snapshot.gridCompanyId,
            gridCompanyName: snapshot.gridCompanyName,
            fuseSize: snapshot.fuseSize,
            gridMonthlyFee: snapshot.gridMonthlyFee,
            gridTransferOrePerKWh: snapshot.gridTransferOrePerKWh,
            gridCostSource: snapshot.gridCostSource.flatMap(TariffSource.init(rawValue:)),
            energyTaxOrePerKWh: snapshot.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: snapshot.certificateFeeOrePerKWh,
            vatRate: snapshot.vatRate,
            effectTariff: nil,
            confidence: CostConfidence(rawValue: snapshot.confidence) ?? .userConfigured,
            source: TariffSource(rawValue: snapshot.source) ?? .userEntered,
            tariffLastUpdated: snapshot.tariffLastUpdated,
            tariffValidUntil: snapshot.tariffValidUntil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case priceArea
        case retailContractType
        case retailerMarkupOrePerKWh
        case contractPriceOrePerKWh
        case retailerMonthlyFee
        case retailContractSource
        case gridCompanyId
        case gridCompanyName
        case fuseSize
        case gridMonthlyFee
        case gridTransferOrePerKWh
        case gridCostSource
        case energyTaxOrePerKWh
        case certificateFeeOrePerKWh
        case vatRate
        case effectTariff
        case confidence
        case source
        case tariffLastUpdated
        case tariffValidUntil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decodeIfPresent(TariffSource.self, forKey: .source) ?? .defaultEstimate
        let retailerMarkup = try container.decodeIfPresent(Double.self, forKey: .retailerMarkupOrePerKWh) ?? CostProfile.SwedishDefaults.retailerMarkupOrePerKWh
        let retailerMonthlyFee = try container.decodeIfPresent(Double.self, forKey: .retailerMonthlyFee) ?? CostProfile.SwedishDefaults.retailerMonthlyFee
        let hasCustomRetailValues = retailerMarkup != CostProfile.SwedishDefaults.retailerMarkupOrePerKWh || retailerMonthlyFee != CostProfile.SwedishDefaults.retailerMonthlyFee

        self.init(
            priceArea: try container.decodeIfPresent(String.self, forKey: .priceArea) ?? CostProfile.SwedishDefaults.priceArea,
            retailContractType: try container.decodeIfPresent(RetailContractType.self, forKey: .retailContractType) ?? .spotPriceMarkup,
            retailerMarkupOrePerKWh: retailerMarkup,
            contractPriceOrePerKWh: try container.decodeIfPresent(Double.self, forKey: .contractPriceOrePerKWh),
            retailerMonthlyFee: retailerMonthlyFee,
            retailContractSource: try container.decodeIfPresent(TariffSource.self, forKey: .retailContractSource) ?? (hasCustomRetailValues ? .userEntered : .defaultEstimate),
            gridCompanyId: try container.decodeIfPresent(String.self, forKey: .gridCompanyId),
            gridCompanyName: try container.decodeIfPresent(String.self, forKey: .gridCompanyName),
            fuseSize: try container.decodeIfPresent(Int.self, forKey: .fuseSize),
            gridMonthlyFee: try container.decodeIfPresent(Double.self, forKey: .gridMonthlyFee),
            gridTransferOrePerKWh: try container.decodeIfPresent(Double.self, forKey: .gridTransferOrePerKWh),
            gridCostSource: try container.decodeIfPresent(TariffSource.self, forKey: .gridCostSource),
            energyTaxOrePerKWh: try container.decodeIfPresent(Double.self, forKey: .energyTaxOrePerKWh) ?? CostProfile.SwedishDefaults.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: try container.decodeIfPresent(Double.self, forKey: .certificateFeeOrePerKWh) ?? CostProfile.SwedishDefaults.certificateFeeOrePerKWh,
            vatRate: try container.decodeIfPresent(Double.self, forKey: .vatRate) ?? CostProfile.SwedishDefaults.vatRate,
            effectTariff: try container.decodeIfPresent(EffectTariff.self, forKey: .effectTariff),
            confidence: try container.decodeIfPresent(CostConfidence.self, forKey: .confidence) ?? .estimated,
            source: source,
            tariffLastUpdated: try container.decodeIfPresent(Date.self, forKey: .tariffLastUpdated),
            tariffValidUntil: try container.decodeIfPresent(Date.self, forKey: .tariffValidUntil)
        )
    }
}

extension CostProfile {
    nonisolated enum SwedishDefaults {
        static let priceArea = "SE3"
        static let retailerMarkupOrePerKWh = 4.0
        static let retailerMonthlyFee = 0.0
        /// Today's standard energy tax from `HistoricalTariffRates`, öre/kWh including VAT.
        static var energyTaxOrePerKWh: Double {
            HistoricalTariffRates.energyTax(for: .standard, on: Date()) ?? 45.0
        }
        static let certificateFeeOrePerKWh = 1.75
        /// Consumer VAT. Profile amounts other than Nord Pool spot are stored including this rate.
        static let vatRate = 0.25
    }

    static func swedishDefaultEstimate(priceArea: String = SwedishDefaults.priceArea) -> CostProfile {
        CostProfile(
            priceArea: priceArea,
            retailContractType: .spotPriceMarkup,
            retailerMarkupOrePerKWh: SwedishDefaults.retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: nil,
            retailerMonthlyFee: SwedishDefaults.retailerMonthlyFee,
            retailContractSource: .defaultEstimate,
            gridCompanyId: nil,
            gridCompanyName: nil,
            fuseSize: nil,
            gridMonthlyFee: nil,
            gridTransferOrePerKWh: nil,
            gridCostSource: nil,
            energyTaxOrePerKWh: SwedishDefaults.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: SwedishDefaults.certificateFeeOrePerKWh,
            vatRate: SwedishDefaults.vatRate,
            effectTariff: nil,
            confidence: .estimated,
            source: .defaultEstimate,
            tariffLastUpdated: nil,
            tariffValidUntil: nil
        )
    }

    nonisolated func updating(
        priceArea: String? = nil,
        retailContractType: RetailContractType? = nil,
        retailerMarkupOrePerKWh: Double? = nil,
        contractPriceOrePerKWh: Double? = nil,
        retailerMonthlyFee: Double? = nil,
        retailContractSource: TariffSource? = nil,
        gridCompanyId: String? = nil,
        gridCompanyName: String? = nil,
        fuseSize: Int? = nil,
        gridMonthlyFee: Double? = nil,
        gridTransferOrePerKWh: Double? = nil,
        gridCostSource: TariffSource? = nil,
        energyTaxOrePerKWh: Double? = nil,
        certificateFeeOrePerKWh: Double? = nil,
        confidence: CostConfidence? = nil,
        source: TariffSource? = nil,
        tariffLastUpdated: Date? = nil,
        tariffValidUntil: Date? = nil
    ) -> CostProfile {
        CostProfile(
            priceArea: priceArea ?? self.priceArea,
            retailContractType: retailContractType ?? self.retailContractType,
            retailerMarkupOrePerKWh: retailerMarkupOrePerKWh ?? self.retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: contractPriceOrePerKWh ?? self.contractPriceOrePerKWh,
            retailerMonthlyFee: retailerMonthlyFee ?? self.retailerMonthlyFee,
            retailContractSource: retailContractSource ?? self.retailContractSource,
            gridCompanyId: gridCompanyId ?? self.gridCompanyId,
            gridCompanyName: gridCompanyName ?? self.gridCompanyName,
            fuseSize: fuseSize ?? self.fuseSize,
            gridMonthlyFee: gridMonthlyFee ?? self.gridMonthlyFee,
            gridTransferOrePerKWh: gridTransferOrePerKWh ?? self.gridTransferOrePerKWh,
            gridCostSource: gridCostSource ?? self.gridCostSource,
            energyTaxOrePerKWh: energyTaxOrePerKWh ?? self.energyTaxOrePerKWh,
            certificateFeeOrePerKWh: certificateFeeOrePerKWh ?? self.certificateFeeOrePerKWh,
            vatRate: vatRate,
            effectTariff: effectTariff,
            confidence: confidence ?? self.confidence,
            source: source ?? self.source,
            tariffLastUpdated: tariffLastUpdated ?? self.tariffLastUpdated,
            tariffValidUntil: tariffValidUntil ?? self.tariffValidUntil
        )
    }

    func removingGridCosts(
        gridCompanyId: String? = nil,
        gridCompanyName: String? = nil,
        fuseSize: Int? = nil,
        confidence: CostConfidence? = nil,
        source: TariffSource? = nil
    ) -> CostProfile {
        CostProfile(
            priceArea: priceArea,
            retailContractType: retailContractType,
            retailerMarkupOrePerKWh: retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: contractPriceOrePerKWh,
            retailerMonthlyFee: retailerMonthlyFee,
            retailContractSource: retailContractSource,
            gridCompanyId: gridCompanyId,
            gridCompanyName: gridCompanyName,
            fuseSize: fuseSize,
            gridMonthlyFee: nil,
            gridTransferOrePerKWh: nil,
            gridCostSource: nil,
            energyTaxOrePerKWh: energyTaxOrePerKWh,
            certificateFeeOrePerKWh: certificateFeeOrePerKWh,
            vatRate: vatRate,
            effectTariff: effectTariff,
            confidence: confidence ?? self.confidence,
            source: source ?? self.source,
            tariffLastUpdated: nil,
            tariffValidUntil: nil
        )
    }

    func settingEffectTariff(
        _ effectTariff: EffectTariff?,
        confidence: CostConfidence? = nil,
        source: TariffSource? = nil
    ) -> CostProfile {
        CostProfile(
            priceArea: priceArea,
            retailContractType: retailContractType,
            retailerMarkupOrePerKWh: retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: contractPriceOrePerKWh,
            retailerMonthlyFee: retailerMonthlyFee,
            retailContractSource: retailContractSource,
            gridCompanyId: gridCompanyId,
            gridCompanyName: gridCompanyName,
            fuseSize: fuseSize,
            gridMonthlyFee: gridMonthlyFee,
            gridTransferOrePerKWh: gridTransferOrePerKWh,
            gridCostSource: gridCostSource,
            energyTaxOrePerKWh: energyTaxOrePerKWh,
            certificateFeeOrePerKWh: certificateFeeOrePerKWh,
            vatRate: vatRate,
            effectTariff: effectTariff,
            confidence: confidence ?? self.confidence,
            source: source ?? self.source,
            tariffLastUpdated: tariffLastUpdated,
            tariffValidUntil: tariffValidUntil
        )
    }

    func settingRetailContract(
        type: RetailContractType,
        retailerMarkupOrePerKWh: Double? = nil,
        contractPriceOrePerKWh: Double? = nil,
        retailerMonthlyFee: Double? = nil,
        retailContractSource: TariffSource? = nil,
        confidence: CostConfidence? = nil,
        source: TariffSource? = nil
    ) -> CostProfile {
        CostProfile(
            priceArea: priceArea,
            retailContractType: type,
            retailerMarkupOrePerKWh: retailerMarkupOrePerKWh ?? self.retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: contractPriceOrePerKWh,
            retailerMonthlyFee: retailerMonthlyFee ?? self.retailerMonthlyFee,
            retailContractSource: retailContractSource ?? self.retailContractSource,
            gridCompanyId: gridCompanyId,
            gridCompanyName: gridCompanyName,
            fuseSize: fuseSize,
            gridMonthlyFee: gridMonthlyFee,
            gridTransferOrePerKWh: gridTransferOrePerKWh,
            gridCostSource: gridCostSource,
            energyTaxOrePerKWh: energyTaxOrePerKWh,
            certificateFeeOrePerKWh: certificateFeeOrePerKWh,
            vatRate: vatRate,
            effectTariff: effectTariff,
            confidence: confidence ?? self.confidence,
            source: source ?? self.source,
            tariffLastUpdated: tariffLastUpdated,
            tariffValidUntil: tariffValidUntil
        )
    }

    var isTariffExpired: Bool {
        guard let tariffValidUntil else { return false }
        return tariffValidUntil < Date()
    }

    var hasCustomRetailContract: Bool {
        retailContractType != .spotPriceMarkup ||
        contractPriceOrePerKWh != nil ||
        retailerMarkupOrePerKWh != SwedishDefaults.retailerMarkupOrePerKWh ||
        retailerMonthlyFee != SwedishDefaults.retailerMonthlyFee
    }

    var hasConfiguredGridCosts: Bool {
        gridMonthlyFee != nil || gridTransferOrePerKWh != nil
    }

    var hasUserEnteredGridCosts: Bool {
        gridCostSource == .userEntered && hasConfiguredGridCosts
    }

    func normalizedGridCostSource() -> CostProfile {
        guard hasConfiguredGridCosts, gridCostSource == nil else {
            return self
        }

        let inferredGridSource: TariffSource
        switch source {
        case .userEntered:
            inferredGridSource = .userEntered
        case .localPreset, .remoteTariff:
            inferredGridSource = source
        case .defaultEstimate, .providerData:
            inferredGridSource = .userEntered
        }

        return updating(gridCostSource: inferredGridSource)
    }

    var hasEnabledEffectTariff: Bool {
        effectTariff != nil
    }

    var isSpotFollowingRetailContract: Bool {
        retailContractType == .spotPriceMarkup
    }

    var retailContractDisplayName: String {
        switch retailContractType {
        case .spotPriceMarkup:
            return "Kvartspris"
        case .variableMonthlyPrice:
            return "Rörligt månadspris"
        case .fixedPrice:
            return "Fast pris"
        }
    }

    var retailContractCostBasisText: String? {
        switch retailContractType {
        case .spotPriceMarkup:
            return nil
        case .variableMonthlyPrice:
            return "Totalpriset använder rörligt månadspris för elhandeln, inklusive moms."
        case .fixedPrice:
            return "Totalpriset använder fast pris för elhandeln, inklusive moms."
        }
    }

    var hasUserConfiguredCostValues: Bool {
        hasCustomRetailContract || hasConfiguredGridCosts || hasEnabledEffectTariff
    }

    func inferredConfidence(preservingProviderConnected: Bool = true) -> CostConfidence {
        if preservingProviderConnected && confidence == .providerConnected {
            return .providerConnected
        }
        return hasUserConfiguredCostValues ? .userConfigured : .estimated
    }

    func applyingInferredConfidence(
        preservingProviderConnected: Bool = true,
        configuredSource: TariffSource? = nil,
        estimatedSource: TariffSource = .defaultEstimate
    ) -> CostProfile {
        let nextConfidence = inferredConfidence(preservingProviderConnected: preservingProviderConnected)
        let nextSource: TariffSource

        switch nextConfidence {
        case .providerConnected:
            nextSource = source
        case .userConfigured:
            nextSource = configuredSource ?? source
        case .estimated:
            nextSource = estimatedSource
        }

        return updating(
            confidence: nextConfidence,
            source: nextSource
        )
    }
}

// MARK: - Retail Contract

nonisolated enum RetailContractType: String, Codable, Equatable, Sendable {
    case spotPriceMarkup
    case variableMonthlyPrice
    case fixedPrice
}

// MARK: - Confidence

nonisolated enum CostConfidence: String, Codable, Equatable, Sendable {
    case estimated
    case userConfigured
    case providerConnected

    var menuBarLabel: String? {
        switch self {
        case .estimated:
            return "Uppskattat"
        case .userConfigured:
            return "Anpassat"
        case .providerConnected:
            return nil
        }
    }
}

// MARK: - Source

nonisolated enum TariffSource: String, Codable, Equatable, Sendable {
    case defaultEstimate
    case userEntered
    case localPreset
    case remoteTariff
    case providerData
}

// MARK: - Effect Tariff

nonisolated struct EffectTariff: Codable, Equatable, Sendable {
    let monthlyPricePerKW: Double
    let model: EffectTariffModel
    let activeHours: EffectTariffActiveHours
}

nonisolated enum EffectTariffModel: String, Codable, Equatable, Sendable {
    case singlePeak
    case averageTopThree
    case averageTopFive
    case manual
}

nonisolated enum EffectTariffActiveHours: String, Codable, Equatable, Sendable {
    case allHours
    case weekdaysDaytime
    case custom
}

// MARK: - Versions over time

/// One saved version of the household's agreement and fees, and the day it applies from.
///
/// The profile belongs to the household, not to the connected data source. A change is
/// saved as a new version from the start of the day it is made, in Swedish time.
/// Changes only apply forward: no version is ever dated back in time.
nonisolated struct CostProfileVersion: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    /// Start of the first day this version applies (Europe/Stockholm).
    /// `distantPast` for the version that was in use before versions were saved.
    let validFrom: Date
    let profile: CostProfile
    let source: TariffSource
    /// Not used yet. Meant for values that are estimates until the bill is known.
    let isPreliminary: Bool
}

/// Picks and saves `CostProfileVersion`s. Pure functions, so they can be checked without storage.
nonisolated enum CostProfileHistory {
    static func dayStart(of date: Date, calendar: Calendar = .energyHistory) -> Date {
        calendar.startOfDay(for: date)
    }

    /// The version in force at `date`: the latest one starting on or before it.
    /// A date before the first version gets the first version.
    static func version(on date: Date, in versions: [CostProfileVersion]) -> CostProfileVersion? {
        let sorted = versions.sorted { $0.validFrom < $1.validFrom }
        return sorted.last { $0.validFrom <= date } ?? sorted.first
    }

    static func profile(on date: Date, in versions: [CostProfileVersion]) -> CostProfile? {
        version(on: date, in: versions)?.profile
    }

    /// Saves `profile` as the version from the start of the day of `date` (normally now).
    ///
    /// - Nothing changes when that profile is already in force.
    /// - A version that already starts that day is replaced, so editing a field several
    ///   times in one day leaves one version for the day, not a stack of them.
    /// - If the day's version ends up equal to the one before it, it is dropped.
    /// - A version dated after that day (only possible if the clock was wrong) is dropped,
    ///   since the latest change is what applies from today.
    static func saving(
        _ profile: CostProfile,
        on date: Date,
        to versions: [CostProfileVersion],
        isPreliminary: Bool = false,
        calendar: Calendar = .energyHistory
    ) -> [CostProfileVersion] {
        let validFrom = dayStart(of: date, calendar: calendar)
        var next = versions
            .filter { $0.validFrom <= validFrom }
            .sorted { $0.validFrom < $1.validFrom }

        if next.count == versions.count,
           let current = version(on: validFrom, in: next),
           current.profile == profile,
           current.isPreliminary == isPreliminary {
            return next
        }

        let sameDay = next.firstIndex { $0.validFrom == validFrom }
        let version = CostProfileVersion(
            id: sameDay.map { next[$0].id } ?? UUID(),
            validFrom: validFrom,
            profile: profile,
            source: profile.source,
            isPreliminary: isPreliminary
        )
        if let sameDay {
            next[sameDay] = version
        } else {
            next.append(version)
        }

        // Back to what applied before today: today's version adds nothing.
        if next.count >= 2 {
            let last = next[next.count - 1]
            let previous = next[next.count - 2]
            if last.validFrom == validFrom,
               last.profile == previous.profile,
               last.isPreliminary == previous.isPreliminary {
                next.removeLast()
            }
        }
        return next
    }

    /// First start with versions: the profile in use becomes the first version, valid
    /// from `distantPast`, so all saved history keeps the profile it was priced with.
    /// Does nothing when versions already exist, so it is safe to run on every start.
    static func migrated(
        _ versions: [CostProfileVersion],
        currentProfile: CostProfile
    ) -> [CostProfileVersion] {
        guard versions.isEmpty else { return versions }
        return [
            CostProfileVersion(
                id: UUID(),
                validFrom: .distantPast,
                profile: currentProfile,
                source: currentProfile.source,
                isPreliminary: false
            )
        ]
    }

    static func encoded(_ versions: [CostProfileVersion]) -> Data? {
        try? JSONEncoder().encode(versions.sorted { $0.validFrom < $1.validFrom })
    }

    static func decoded(_ data: Data?) -> [CostProfileVersion] {
        guard let data,
              let versions = try? JSONDecoder().decode([CostProfileVersion].self, from: data) else {
            return []
        }
        return versions.sorted { $0.validFrom < $1.validFrom }
    }
}

/// Which agreement version and which fees price a moment in saved history.
///
/// - Every interval gets the version in force when it started (`CostProfileHistory.version(on:)`)
///   with the fees of `HistoricalTariffRates` for that date on top.
/// - The newest version is the profile the app uses now (`current`), so history
///   without a change is priced exactly as before versions existed.
/// - Forecasts and "right now" do not use this. They use today's profile.
nonisolated enum HistoryPricing {
    static let versionsKey = "settings_costProfileVersions"
    private static let realSuiteName = "group.mb.Spotprice"
    private static let demoSuiteName = "mb.Spotprice.demo"

    private struct Cache: Sendable {
        var suite = ""
        var data: Data?
        var versions: [CostProfileVersion] = []
    }

    private static let cache = OSAllocatedUnfairLock(initialState: Cache())

    /// The saved versions, from the demo store while demo mode is on. Decoded once per change.
    static func savedVersions() -> [CostProfileVersion] {
        let suite = DemoMode.isActive ? demoSuiteName : realSuiteName
        let data = UserDefaults(suiteName: suite)?.data(forKey: versionsKey)
        return cache.withLock { cache in
            if cache.suite == suite, cache.data == data {
                return cache.versions
            }
            cache.suite = suite
            cache.data = data
            cache.versions = CostProfileHistory.decoded(data)
            return cache.versions
        }
    }

    /// The version in force at `date`, or nil when it is the newest one (or there are none).
    static func olderVersion(at date: Date, in versions: [CostProfileVersion]) -> CostProfileVersion? {
        guard let version = CostProfileHistory.version(on: date, in: versions),
              let newest = versions.max(by: { $0.validFrom < $1.validFrom }),
              version.id != newest.id else {
            return nil
        }
        return version
    }

    /// Profile for a past period: the version at `date` with that date's fees.
    static func periodProfile(
        at date: Date,
        current: CostProfile,
        versions: [CostProfileVersion]
    ) -> CostProfile {
        let base = olderVersion(at: date, in: versions)?.profile ?? current
        return HistoricalTariffRates.profile(base, forPeriodStarting: date)
    }

    static func periodProfile(at date: Date, current: CostProfile) -> CostProfile {
        periodProfile(at: date, current: current, versions: savedVersions())
    }

    /// Profile for the running month, which used today's profile as it is. Days under an
    /// older version get that version with their fees, the rest keep `current` untouched.
    static func liveProfile(
        at date: Date,
        current: CostProfile,
        versions: [CostProfileVersion]
    ) -> CostProfile {
        guard let version = olderVersion(at: date, in: versions) else { return current }
        return HistoricalTariffRates.profile(version.profile, forPeriodStarting: date)
    }

    static func liveProfile(at date: Date, current: CostProfile) -> CostProfile {
        liveProfile(at: date, current: current, versions: savedVersions())
    }

    /// True when a version starts inside the interval (after its start), so one profile
    /// cannot describe all of it.
    static func hasVersionChange(in interval: Foundation.DateInterval, versions: [CostProfileVersion]) -> Bool {
        versions.contains { $0.validFrom > interval.start && $0.validFrom < interval.end }
    }

    /// The base for repricing a saved interval, before the date's fees.
    ///
    /// - Under the first version (from `distantPast`) the interval keeps the profile saved
    ///   with it, as before versions existed. Without one, the first version's profile,
    ///   or `fallback` while that is still the newest.
    /// - Under a later version, that version's profile, through the same snapshot round
    ///   trip as saved profiles so both are compared on equal terms.
    static func recordBase(
        at date: Date,
        saved: CostProfile?,
        fallback: CostProfile,
        versions: [CostProfileVersion]
    ) -> (profile: CostProfile, version: CostProfileVersion?) {
        guard let version = CostProfileHistory.version(on: date, in: versions) else {
            return (saved ?? fallback, nil)
        }
        if version.validFrom == .distantPast {
            if let saved { return (saved, nil) }
            return (olderVersion(at: date, in: versions)?.profile ?? fallback, nil)
        }
        return (normalized(version.profile, capturedAt: version.validFrom), version)
    }

    static func normalized(_ profile: CostProfile, capturedAt: Date) -> CostProfile {
        CostProfile(historySnapshot: HistoricalCostProfileSnapshot(profile: profile, capturedAt: capturedAt)) ?? profile
    }

    /// Fixed monthly fees (with VAT) over `interval`, spread per day by the profile of each day.
    /// For a month with one profile this equals the monthly fee times hours / 730.
    static func fixedFeesKr(
        in interval: Foundation.DateInterval,
        profileForDay: (Date) -> CostProfile,
        calendar: Calendar = .energyHistory
    ) -> Double {
        var total = 0.0
        var dayStart = calendar.startOfDay(for: interval.start)
        while dayStart < interval.end {
            let next = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? interval.end
            let from = max(dayStart, interval.start)
            let to = min(next, interval.end)
            let hours = max(to.timeIntervalSince(from) / 3600, 0)
            let profile = profileForDay(dayStart)
            let monthly = (profile.gridMonthlyFee ?? 0) + profile.retailerMonthlyFee
            // Monthly fees are entered with VAT, as in `TotalCostService`.
            total += monthly * hours / 730
            dayStart = next
        }
        return total
    }

    /// True when some day of `month` lies under an older version than today's.
    static func monthHasOlderVersion(_ month: Foundation.DateInterval, versions: [CostProfileVersion]) -> Bool {
        olderVersion(at: month.start, in: versions) != nil
    }

    /// The running month: what its days under an older version cost compared with pricing
    /// them with today's profile (old minus current, per cost line). Live totals and the
    /// forecast are priced with today's profile, so adding this gives older days their own
    /// version while the rest of the month stays on today's. Nil when no interval is affected.
    static func liveAdjustment(
        intervals: [(start: Date, end: Date, kWh: Double, spotOre: Double)],
        current: CostProfile,
        versions: [CostProfileVersion],
        calendar: Calendar = .energyHistory
    ) -> EnhancedCost? {
        let service = TotalCostService.shared
        var profiles: [String: CostProfile] = [:]
        var total: EnhancedCost?
        for interval in intervals where interval.kWh > 0 {
            guard let version = olderVersion(at: interval.start, in: versions) else { continue }
            let dayKey = "\(version.id.uuidString)|\(calendar.startOfDay(for: interval.start).timeIntervalSinceReferenceDate)"
            let old = profiles[dayKey] ?? HistoricalTariffRates.profile(version.profile, forPeriodStarting: interval.start)
            profiles[dayKey] = old
            let hours = max(interval.end.timeIntervalSince(interval.start) / 3600, 0)
            let then = service.calculateTotalCost(kWh: interval.kWh, spotPriceOre: interval.spotOre, profile: old, hoursInPeriod: hours)
            let now = service.calculateTotalCost(kWh: interval.kWh, spotPriceOre: interval.spotOre, profile: current, hoursInPeriod: hours)
            total = (total ?? .zero).adding(then).adding(now, scale: -1)
        }
        return total
    }

    /// Where repricing must start after the versions changed from `old` to `new`.
    /// Nil when nothing that prices history changed. Without an earlier record (`old` nil)
    /// the first version needs nothing; any later version is priced from its start.
    static func repriceStart(old: [CostProfileVersion]?, new: [CostProfileVersion]) -> Date? {
        guard let old else {
            return new.filter { $0.validFrom != .distantPast }.map(\.validFrom).min()
        }
        let changed = old.filter { !new.contains($0) } + new.filter { !old.contains($0) }
        return changed.map(\.validFrom).min()
    }
}

#if DEBUG
/// Checks the version rules once in DEBUG builds, in the same way as `WorkedExampleGuard`.
nonisolated enum CostProfileVersionGuard {
    static let isValid: Bool = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
        }
        let a = ElectricityCostMath.workedExampleSE3Jonkoping20A()
        let b = a.updating(retailerMarkupOrePerKWh: 6)
        let c = a.updating(retailerMarkupOrePerKWh: 7)
        var ok = true
        func check(_ condition: Bool, _ message: String) {
            assert(condition, "CostProfileVersion: \(message)")
            ok = ok && condition
        }

        // Migration, and running it twice.
        let first = CostProfileHistory.migrated([], currentProfile: a)
        check(first.count == 1 && first[0].validFrom == .distantPast && first[0].profile == a, "migration")
        check(CostProfileHistory.migrated(first, currentProfile: b) == first, "migration twice")

        // Switch day in spring, the day clocks go forward (2026-03-29).
        let spring = CostProfileHistory.saving(b, on: at(2026, 3, 29, 14, 30), to: first, calendar: calendar)
        check(spring.count == 2 && spring[1].validFrom == at(2026, 3, 29), "spring validFrom")
        check(spring[1].validFrom == Date(timeIntervalSince1970: 1_774_738_800), "spring validFrom is 23:00 UTC the day before")
        check(CostProfileHistory.profile(on: at(2026, 3, 28, 23, 59), in: spring) == a, "day before switch")
        check(CostProfileHistory.profile(on: at(2026, 3, 29), in: spring) == b, "switch day midnight")
        check(CostProfileHistory.profile(on: at(2026, 3, 29, 23, 59), in: spring) == b, "late on DST day")
        check(CostProfileHistory.profile(on: at(2024, 1, 1), in: spring) == a, "old history keeps first version")

        // Same day again: replaced, not stacked. Back to the earlier profile: dropped.
        let sameDay = CostProfileHistory.saving(c, on: at(2026, 3, 29, 20), to: spring, calendar: calendar)
        check(sameDay.count == 2 && sameDay[1].profile == c && sameDay[1].id == spring[1].id, "same day replaces")
        let reverted = CostProfileHistory.saving(a, on: at(2026, 3, 29, 21), to: sameDay, calendar: calendar)
        check(reverted == first, "back to earlier profile the same day")
        check(CostProfileHistory.saving(b, on: at(2026, 3, 30, 9), to: spring, calendar: calendar) == spring, "unchanged profile is a no-op")

        // Autumn, the day clocks go back (2026-10-25 has 25 hours).
        let autumn = CostProfileHistory.saving(c, on: at(2026, 10, 25, 2, 30), to: spring, calendar: calendar)
        check(autumn.count == 3 && autumn[2].validFrom == Date(timeIntervalSince1970: 1_792_879_200), "autumn validFrom is 22:00 UTC the day before")
        check(CostProfileHistory.profile(on: at(2026, 10, 24, 23, 59), in: autumn) == b, "day before autumn switch")
        check(CostProfileHistory.profile(on: at(2026, 10, 25, 23, 59), in: autumn) == c, "late on autumn DST day")

        // Saved and read back.
        check(CostProfileHistory.decoded(CostProfileHistory.encoded(autumn)) == autumn, "JSON round trip")
        return ok
    }()
}
#endif

#if DEBUG
/// Checks that history picks the agreement version per interval, in the same way as
/// `CostProfileVersionGuard`.
nonisolated enum HistoryPricingGuard {
    static let isValid: Bool = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
        }
        var ok = true
        func check(_ condition: Bool, _ message: String) {
            assert(condition, "HistoryPricing: \(message)")
            ok = ok && condition
        }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000_001 }

        let a = ElectricityCostMath.workedExampleSE3Jonkoping20A()
        let b = a.updating(retailerMonthlyFee: a.retailerMonthlyFee + 30, gridMonthlyFee: (a.gridMonthlyFee ?? 0) + 100)
        let first = CostProfileHistory.migrated([], currentProfile: a)
        let october = at(2025, 10, 10, 13)

        // Without a change everything prices as before versions: the table on top of today's profile.
        for versions in [[], first] {
            check(HistoryPricing.periodProfile(at: october, current: a, versions: versions)
                == HistoricalTariffRates.profile(a, forPeriodStarting: october), "no change, past period")
            check(HistoryPricing.liveProfile(at: october, current: a, versions: versions) == a, "no change, running month")
        }

        // A change from 2026-11-12: older intervals keep a, the new day and later get b.
        let change = CostProfileHistory.saving(b, on: at(2026, 11, 12, 9), to: first, calendar: calendar)
        check(change.count == 2, "change saved")
        check(HistoryPricing.periodProfile(at: at(2026, 11, 11, 23, 45), current: b, versions: change)
            == HistoricalTariffRates.profile(a, forPeriodStarting: at(2026, 11, 11, 23, 45)), "quarter before the change")
        check(HistoryPricing.periodProfile(at: at(2026, 11, 12), current: b, versions: change)
            == HistoricalTariffRates.profile(b, forPeriodStarting: at(2026, 11, 12)), "quarter at the change")
        check(HistoryPricing.liveProfile(at: at(2026, 11, 12, 5), current: b, versions: change) == b, "today keeps today's profile")
        check(HistoryPricing.periodProfile(at: october, current: b, versions: change)
            == HistoricalTariffRates.profile(a, forPeriodStarting: october), "October untouched")

        // Only what changed is priced again, from its first day.
        check(HistoryPricing.repriceStart(old: nil, new: first) == nil, "first version needs no repricing")
        check(HistoryPricing.repriceStart(old: first, new: first) == nil, "same versions")
        check(HistoryPricing.repriceStart(old: first, new: change) == at(2026, 11, 12), "new version from its day")
        check(HistoryPricing.repriceStart(old: nil, new: change) == at(2026, 11, 12), "unknown earlier state")

        // Repricing a saved row: the first version keeps the saved profile, later ones use theirs.
        let saved = HistoryPricing.normalized(a.updating(retailerMarkupOrePerKWh: 9), capturedAt: october)
        check(HistoryPricing.recordBase(at: october, saved: saved, fallback: b, versions: change).profile == saved, "saved profile under first version")
        let later = HistoryPricing.recordBase(at: at(2026, 11, 12, 3), saved: saved, fallback: b, versions: change)
        check(later.profile == HistoryPricing.normalized(b, capturedAt: at(2026, 11, 12)) && later.version != nil, "later version wins over saved")

        // A change mid-month (test data, 2025-10-15): every quarter gets its own version,
        // and the fixed fees follow the days. Summed per quarter they match the per-day spread.
        let mid = CostProfileHistory.saving(b, on: at(2025, 10, 15, 12), to: first, calendar: calendar)
        let current = b
        let service = TotalCostService.shared
        guard let month = calendar.dateInterval(of: .month, for: october) else { return false }
        var start = month.start
        var perQuarterFees = 0.0
        var quartersA = 0
        var quartersB = 0
        while start < month.end {
            let profile = HistoryPricing.periodProfile(at: start, current: current, versions: mid)
            let cost = service.calculateTotalCost(kWh: 0.25, spotPriceOre: 50, profile: profile, hoursInPeriod: 0.25)
            // Cost parts are without VAT; the monthly fees are entered with it.
            perQuarterFees += (cost.fixedFeeCostKr + cost.providerMonthlyFeeKr) * (1 + profile.vatRate)
            if profile.retailerMonthlyFee == a.retailerMonthlyFee { quartersA += 1 } else { quartersB += 1 }
            start = start.addingTimeInterval(15 * 60)
        }
        // October 2025 has 31 days and 25 hours on the 26th: 14 days of a, 17 days of b.
        check(quartersA == 14 * 96 && quartersB == 17 * 96 + 4, "quarters split at the change")
        check(HistoryPricing.hasVersionChange(in: month, versions: mid), "change found in month")
        check(!HistoryPricing.hasVersionChange(in: month, versions: change), "no change in October")
        let perDay = HistoryPricing.fixedFeesKr(in: month, profileForDay: { day in
            HistoryPricing.periodProfile(at: day, current: current, versions: mid)
        }, calendar: calendar)
        check(near(perQuarterFees, perDay), "fixed fees per quarter equal the per-day spread")

        // A month without a change: the same fixed fee as one profile over the month.
        let single = HistoryPricing.fixedFeesKr(in: month, profileForDay: { day in
            HistoryPricing.periodProfile(at: day, current: a, versions: first)
        }, calendar: calendar)
        let rated = HistoricalTariffRates.profile(a, forPeriodStarting: month.start)
        let whole = service.calculateTotalCost(kWh: 0, spotPriceOre: 0, profile: rated, hoursInPeriod: month.duration / 3600)
        check(near(single, (whole.fixedFeeCostKr + whole.providerMonthlyFeeKr) * (1 + rated.vatRate)), "whole month unchanged")

        // Running month with a change on the 15th: only the days before it are adjusted,
        // by old minus current price, and nothing at all without a change.
        var live: [(start: Date, end: Date, kWh: Double, spotOre: Double)] = []
        var expected = 0.0
        var quarterStart = month.start
        while quarterStart < at(2025, 10, 20) {
            let end = quarterStart.addingTimeInterval(900)
            live.append((quarterStart, end, 0.3, 80))
            if quarterStart < at(2025, 10, 15) {
                let old = HistoricalTariffRates.profile(a, forPeriodStarting: quarterStart)
                expected += service.calculateTotalCost(kWh: 0.3, spotPriceOre: 80, profile: old, hoursInPeriod: 0.25).totalKr
                    - service.calculateTotalCost(kWh: 0.3, spotPriceOre: 80, profile: b, hoursInPeriod: 0.25).totalKr
            }
            quarterStart = end
        }
        let adjustment = HistoryPricing.liveAdjustment(intervals: live, current: b, versions: mid, calendar: calendar)
        check(adjustment.map { near($0.totalKr, expected) } ?? false, "live adjustment covers days before the change")
        check(HistoryPricing.liveAdjustment(intervals: live, current: a, versions: first, calendar: calendar) == nil, "no adjustment without change")
        check(HistoryPricing.monthHasOlderVersion(month, versions: mid) && !HistoryPricing.monthHasOlderVersion(month, versions: first), "month under older version")
        return ok
    }()
}
#endif

// MARK: - Rates by date

/// Which energy tax rate applies. A few northern regions pay a lower rate.
nonisolated enum EnergyTaxRegion: String, Codable, Sendable {
    case standard
    /// Lower rate in parts of northern Sweden, for example Västerbotten.
    case reducedNorth

    /// The region is not stored in the profile, so it follows the grid company preset,
    /// as the presets in `GridTariffService` do.
    static func forGridCompany(_ gridCompanyId: String?) -> EnergyTaxRegion {
        gridCompanyId == "skelleftea" ? .reducedNorth : .standard
    }
}

/// Energy tax from a date, öre/kWh including VAT.
nonisolated struct EnergyTaxRate: Sendable {
    let validFrom: Date
    let region: EnergyTaxRegion
    let orePerKWhInclVAT: Double
}

/// A grid company's fees for one fuse size from a date, including VAT.
nonisolated struct GridFeeRate: Sendable {
    let validFrom: Date
    let gridCompanyId: String
    let fuseSize: Int
    /// kr per month.
    let monthlyFee: Double
    /// öre/kWh.
    let transferOrePerKWh: Double
    /// Effect fee in kr/kW per month. Kept for later. No cost uses it yet.
    let powerFeeKrPerKW: Double?
}

/// The fees that were in force on a given date, as a table of dated rows.
///
/// History must be priced with the rates of its own period. A frozen copy of
/// "today's" profile makes October 2026 look cheaper than November just because
/// the profile was refreshed in between.
///
/// Rules:
/// - A row applies from its `validFrom` until the next row for the same region, or
///   the same grid company and fuse. A date before the first row uses the first row,
///   so older history is priced as it was before the table existed.
/// - Grid fees the user typed in (`gridCostSource == .userEntered`) win over the table.
///   Energy tax cannot be typed in, so it always follows the table when there is a row.
/// - A new year only needs new rows here, plus a bump of `version`.
nonisolated enum HistoricalTariffRates {
    /// Bump when the table below changes, so saved history is priced again once.
    static let version = 3

    static let energyTaxRates: [EnergyTaxRate] = [
        EnergyTaxRate(validFrom: day(2025, 1, 1), region: .standard, orePerKWhInclVAT: 54.875),
        EnergyTaxRate(validFrom: day(2026, 1, 1), region: .standard, orePerKWhInclVAT: 45.0),
        EnergyTaxRate(validFrom: day(2026, 1, 1), region: .reducedNorth, orePerKWhInclVAT: 33.0)
    ]

    /// Vaggeryds Energi (Vaggeryds Elnät), säkringsabonnemang for houses ("villa"), in kr/mån
    /// as the price list states them. The cheaper "16 A lgh" (flat) rate is not in the table,
    /// so a 16 A preset is always the house rate. Säkringskunder pay no effect fee; effect
    /// subscriptions only apply above 200 A.
    /// Source: vaggerydsenergi.se/tjanster/elnat/elnatsavgifter, archived by the Wayback Machine
    /// (2024-06-13, 2024-12-08, 2025-03-24, 2025-10-13) and the live page for 2026.
    /// The list valid until 2024-01-31 is not here: when it started is not documented.
    static let gridFeeRates: [GridFeeRate] =
        gridRows(
            company: "vaggeryd",
            from: day(2024, 2, 1),
            monthlyFees: [16: 427, 20: 688, 25: 906, 35: 1_146, 50: 1_823, 63: 2_292],
            transferOrePerKWh: 27.50,
            powerFeeKrPerKW: nil
        ) +
        gridRows(
            company: "vaggeryd",
            from: day(2025, 2, 1),
            monthlyFees: [16: 442, 20: 711, 25: 938, 35: 1_186, 50: 1_887, 63: 2_372],
            transferOrePerKWh: 28.5,
            powerFeeKrPerKW: nil
        ) +
        gridRows(
            company: "vaggeryd",
            from: day(2026, 1, 1),
            monthlyFees: [16: 458, 20: 742, 25: 975, 35: 1_233, 50: 1_967, 63: 2_475],
            transferOrePerKWh: 29.75,
            powerFeeKrPerKW: nil
        )

    static func energyTax(for region: EnergyTaxRegion, on date: Date) -> Double? {
        let rows = energyTaxRates.filter { $0.region == region }
        return row(in: rows, on: date, validFrom: \.validFrom)?.orePerKWhInclVAT
    }

    static func gridFee(company gridCompanyId: String, fuseSize: Int, on date: Date) -> GridFeeRate? {
        let rows = gridFeeRates.filter { $0.gridCompanyId == gridCompanyId && $0.fuseSize == fuseSize }
        return row(in: rows, on: date, validFrom: \.validFrom)
    }

    /// True when the table has grid fees for this company at all.
    static func hasGridFees(company gridCompanyId: String?) -> Bool {
        guard let gridCompanyId else { return false }
        return gridFeeRates.contains { $0.gridCompanyId == gridCompanyId }
    }

    /// First day the table no longer covers. The latest rows are the price lists and the
    /// energy tax for 2026; what applies after that is not known yet.
    static let documentedUntil = day(2027, 1, 1)

    /// True when the table holds the grid fees that applied on `date`: on or after the
    /// company's first row and before `documentedUntil`. Before the first row the first
    /// row is used, but what applied then is not documented.
    static func documentsGridFees(company gridCompanyId: String?, on date: Date) -> Bool {
        guard let gridCompanyId,
              let first = gridFeeRates.filter({ $0.gridCompanyId == gridCompanyId }).map(\.validFrom).min() else {
            return false
        }
        return date >= first && date < documentedUntil
    }

    /// True when the energy tax for `date` is known. Dates before the first row keep the
    /// first row's rate (Martin's choice for 2024), so only dates after the table count.
    static func documentsEnergyTax(on date: Date) -> Bool {
        date < documentedUntil
    }

    /// `profile` with the fees that applied on `date`.
    static func profile(_ profile: CostProfile, forPeriodStarting date: Date) -> CostProfile {
        var tax: Double?
        var fee: Double?
        var transfer: Double?

        let region = EnergyTaxRegion.forGridCompany(profile.gridCompanyId)
        if let rate = energyTax(for: region, on: date),
           abs(profile.energyTaxOrePerKWh - rate) > 0.0001 {
            tax = rate
        }

        if profile.gridCostSource != .userEntered,
           let company = profile.gridCompanyId,
           let fuse = profile.fuseSize,
           let row = gridFee(company: company, fuseSize: fuse, on: date) {
            if let current = profile.gridMonthlyFee, abs(current - row.monthlyFee) > 0.0001 {
                fee = row.monthlyFee
            }
            if let current = profile.gridTransferOrePerKWh, abs(current - row.transferOrePerKWh) > 0.0001 {
                transfer = row.transferOrePerKWh
            }
        }

        guard tax != nil || fee != nil || transfer != nil else { return profile }
        return profile.updating(
            gridMonthlyFee: fee,
            gridTransferOrePerKWh: transfer,
            energyTaxOrePerKWh: tax
        )
    }

    // MARK: Helpers

    private static func row<Row>(in rows: [Row], on date: Date, validFrom: KeyPath<Row, Date>) -> Row? {
        let sorted = rows.sorted { $0[keyPath: validFrom] < $1[keyPath: validFrom] }
        return sorted.last { $0[keyPath: validFrom] <= date } ?? sorted.first
    }

    private static func gridRows(
        company: String,
        from validFrom: Date,
        monthlyFees: [Int: Double],
        transferOrePerKWh: Double,
        powerFeeKrPerKW: Double?
    ) -> [GridFeeRate] {
        monthlyFees.keys.sorted().map { fuse in
            GridFeeRate(
                validFrom: validFrom,
                gridCompanyId: company,
                fuseSize: fuse,
                monthlyFee: monthlyFees[fuse] ?? 0,
                transferOrePerKWh: transferOrePerKWh,
                powerFeeKrPerKW: powerFeeKrPerKW
            )
        }
    }

    /// Midnight in Swedish time.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.energyHistory.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}

#if DEBUG
/// Checks once in DEBUG builds that the table gives Vaggeryd's published fees
/// for each period, and the energy tax that applied.
nonisolated enum HistoricalTariffRatesGuard {
    static let isValid: Bool = {
        var ok = true
        func check(_ condition: Bool, _ message: String) {
            assert(condition, "HistoricalTariffRates: \(message)")
            ok = ok && condition
        }
        let fees2024: [Int: Double] = [16: 427, 20: 688, 25: 906, 35: 1_146, 50: 1_823, 63: 2_292]
        let fees2025: [Int: Double] = [16: 442, 20: 711, 25: 938, 35: 1_186, 50: 1_887, 63: 2_372]
        let fees2026: [Int: Double] = [16: 458, 20: 742, 25: 975, 35: 1_233, 50: 1_967, 63: 2_475]
        let in2024 = HistoricalTariffRates.day(2024, 11, 15)
        let lastOfJanuary2025 = HistoricalTariffRates.day(2025, 2, 1).addingTimeInterval(-1)
        let firstOfFebruary2025 = HistoricalTariffRates.day(2025, 2, 1)
        let in2025 = HistoricalTariffRates.day(2025, 6, 1)
        let lastOf2025 = HistoricalTariffRates.day(2026, 1, 1).addingTimeInterval(-1)
        let in2026 = HistoricalTariffRates.day(2026, 1, 1)
        let in2027 = HistoricalTariffRates.day(2027, 3, 1)

        for (date, tax) in [(in2024, 54.875), (in2025, 54.875), (lastOf2025, 54.875), (in2026, 45.0), (in2027, 45.0)] {
            check(HistoricalTariffRates.energyTax(for: .standard, on: date) == tax, "energy tax \(date)")
        }
        check(HistoricalTariffRates.energyTax(for: .reducedNorth, on: in2025) == 33.0, "reduced north keeps 33 before 2026")

        func expect(_ fees: [Int: Double], transfer: Double, on dates: [Date], _ label: String) {
            for fuse in fees.keys.sorted() {
                for date in dates {
                    let row = HistoricalTariffRates.gridFee(company: "vaggeryd", fuseSize: fuse, on: date)
                    check(row?.monthlyFee == fees[fuse] && row?.transferOrePerKWh == transfer && row?.powerFeeKrPerKW == nil, "vaggeryd \(label) \(fuse) A")
                }
            }
        }
        expect(fees2024, transfer: 27.50, on: [in2024, lastOfJanuary2025], "2024-02-01")
        expect(fees2025, transfer: 28.5, on: [firstOfFebruary2025, in2025, lastOf2025], "2025-02-01")
        expect(fees2026, transfer: 29.75, on: [in2026, in2027], "2026-01-01")
        check(!HistoricalTariffRates.gridFeeRates.contains { $0.powerFeeKrPerKW != nil }, "no effect fee for säkringskunder")

        // A profile with 2026 preset values, priced for 2025 and back again.
        let preset2026 = ElectricityCostMath.workedExampleSE3Jonkoping20A().updating(
            gridCompanyId: "vaggeryd",
            fuseSize: 16,
            gridMonthlyFee: 458,
            gridTransferOrePerKWh: 29.75,
            gridCostSource: .localPreset,
            energyTaxOrePerKWh: 45
        )
        let as2025 = HistoricalTariffRates.profile(preset2026, forPeriodStarting: in2025)
        check(as2025.gridMonthlyFee == 442 && as2025.gridTransferOrePerKWh == 28.5 && as2025.energyTaxOrePerKWh == 54.875, "2026 preset priced for 2025")
        let asJanuary2025 = HistoricalTariffRates.profile(preset2026, forPeriodStarting: lastOfJanuary2025)
        check(asJanuary2025.gridMonthlyFee == 427 && asJanuary2025.gridTransferOrePerKWh == 27.50, "2026 preset priced for January 2025")
        check(HistoricalTariffRates.profile(as2025, forPeriodStarting: in2026) == preset2026, "back to 2026")
        check(HistoricalTariffRates.profile(preset2026, forPeriodStarting: in2026) == preset2026, "2026 unchanged")

        // Typed in by the user: grid fees stay, energy tax follows the table.
        let typed = preset2026.updating(gridMonthlyFee: 300, gridTransferOrePerKWh: 20, gridCostSource: .userEntered)
        let typed2025 = HistoricalTariffRates.profile(typed, forPeriodStarting: in2025)
        check(typed2025.gridMonthlyFee == 300 && typed2025.gridTransferOrePerKWh == 20 && typed2025.energyTaxOrePerKWh == 54.875, "user-entered grid fees win")
        return ok
    }()
}
#endif

// MARK: - Preliminary values

/// Marks values that may still change, so the app can tell them from settled ones
/// (EIFS: the customer should be able to see when a value is preliminary). The mark never
/// changes an amount.
///
/// Vaggeryd sends no status or quality code with its values, only date, consumption and
/// price, so the rule is the app's own:
/// - A measured value is preliminary when it was fetched before its interval was 48 hours
///   old. The app fetches the last 48 hours again on every load, and Vaggeryd can still
///   correct them. Fetched again after that, the value is settled and loses the mark.
/// - A cost is preliminary when it was priced with something not known yet: an agreement
///   version marked preliminary, a guessed price (default estimate), or table fees for a
///   date the table does not cover.
nonisolated enum HistoryPreliminary {
    /// The window the app fetches again on every load.
    static let refetchWindow: TimeInterval = 48 * 60 * 60

    static func measurementIsPreliminary(intervalEnd: Date, fetchedAt: Date) -> Bool {
        fetchedAt < intervalEnd.addingTimeInterval(refetchWindow)
    }

    /// `profile` is the one the interval was priced with (its snapshot).
    static func costIsPreliminary(profile: CostProfile?, at date: Date, versions: [CostProfileVersion]) -> Bool {
        if CostProfileHistory.version(on: date, in: versions)?.isPreliminary == true { return true }
        guard let profile else { return false }
        if profile.confidence == .estimated { return true }
        if (profile.retailContractSource ?? .defaultEstimate) == .defaultEstimate { return true }
        switch profile.gridCostSource {
        case .userEntered, .providerData, .remoteTariff:
            break
        case .localPreset:
            if !HistoricalTariffRates.documentsGridFees(company: profile.gridCompanyId, on: date) { return true }
        case .defaultEstimate, nil:
            return true
        }
        return !HistoricalTariffRates.documentsEnergyTax(on: date)
    }

    /// The confidence a saved row should have. Only measured rows are marked; price-only
    /// and estimated rows keep theirs. A row that is settled again goes back to measured.
    static func confidence(
        current: HistoricalEnergyConfidence,
        hasConsumption: Bool,
        intervalStart: Date,
        intervalEnd: Date,
        fetchedAt: Date,
        profile: CostProfile?,
        versions: [CostProfileVersion]
    ) -> HistoricalEnergyConfidence {
        guard hasConsumption, [.measured, .partial, .preliminary].contains(current) else { return current }
        if measurementIsPreliminary(intervalEnd: intervalEnd, fetchedAt: fetchedAt)
            || costIsPreliminary(profile: profile, at: intervalStart, versions: versions) {
            return .preliminary
        }
        return current == .preliminary ? .measured : current
    }
}

#if DEBUG
nonisolated enum HistoryPreliminaryGuard {
    static let isValid: Bool = {
        var ok = true
        func check(_ condition: Bool, _ message: String) {
            assert(condition, "HistoryPreliminary: \(message)")
            ok = ok && condition
        }
        let end = HistoricalTariffRates.day(2026, 11, 10)
        let start = end.addingTimeInterval(-15 * 60)
        let hour: TimeInterval = 60 * 60
        check(HistoryPreliminary.measurementIsPreliminary(intervalEnd: end, fetchedAt: end.addingTimeInterval(hour)), "fetched after 1 h")
        check(HistoryPreliminary.measurementIsPreliminary(intervalEnd: end, fetchedAt: end.addingTimeInterval(47 * hour)), "fetched after 47 h")
        check(!HistoryPreliminary.measurementIsPreliminary(intervalEnd: end, fetchedAt: end.addingTimeInterval(48 * hour)), "fetched after 48 h")

        let user = ElectricityCostMath.workedExampleSE3Jonkoping20A().updating(
            retailContractSource: .userEntered,
            gridCostSource: .userEntered
        )
        let preset = user.updating(gridCompanyId: "vaggeryd", fuseSize: 16, gridCostSource: .localPreset)
        let guessed = user.updating(retailContractSource: .defaultEstimate)
        let noGrid = ElectricityCostMath.workedExampleSE3Jonkoping20A().updating(retailContractSource: .userEntered)
        let in2025 = HistoricalTariffRates.day(2025, 6, 1)
        let before2024List = HistoricalTariffRates.day(2024, 1, 15)
        let in2027 = HistoricalTariffRates.day(2027, 2, 1)
        check(!HistoryPreliminary.costIsPreliminary(profile: user, at: in2025, versions: []), "user values are settled")
        check(!HistoryPreliminary.costIsPreliminary(profile: preset, at: in2025, versions: []), "preset with a documented row")
        check(HistoryPreliminary.costIsPreliminary(profile: preset, at: before2024List, versions: []), "preset before the first row")
        check(HistoryPreliminary.costIsPreliminary(profile: preset, at: in2027, versions: []), "preset after the last documented row")
        check(HistoryPreliminary.costIsPreliminary(profile: user, at: in2027, versions: []), "energy tax after the table")
        check(HistoryPreliminary.costIsPreliminary(profile: guessed, at: in2025, versions: []), "guessed retail price")
        if noGrid.gridCostSource == nil || noGrid.gridCostSource == .defaultEstimate {
            check(HistoryPreliminary.costIsPreliminary(profile: noGrid, at: in2025, versions: []), "no grid source")
        }
        let preliminaryVersion = CostProfileVersion(
            id: UUID(), validFrom: HistoricalTariffRates.day(2025, 5, 1), profile: user, source: .userEntered, isPreliminary: true
        )
        let firstVersion = CostProfileVersion(
            id: UUID(), validFrom: .distantPast, profile: user, source: .userEntered, isPreliminary: false
        )
        let versions = [firstVersion, preliminaryVersion]
        check(HistoryPreliminary.costIsPreliminary(profile: user, at: in2025, versions: versions), "preliminary version")
        check(!HistoryPreliminary.costIsPreliminary(profile: user, at: HistoricalTariffRates.day(2025, 4, 1), versions: versions), "before the preliminary version")

        let fetchedLate = end.addingTimeInterval(49 * hour)
        let fetchedEarly = end.addingTimeInterval(2 * hour)
        func confidence(_ current: HistoricalEnergyConfidence, consumption: Bool = true, fetchedAt: Date, profile: CostProfile = user) -> HistoricalEnergyConfidence {
            HistoryPreliminary.confidence(
                current: current, hasConsumption: consumption, intervalStart: start, intervalEnd: end,
                fetchedAt: fetchedAt, profile: profile, versions: []
            )
        }
        check(confidence(.measured, fetchedAt: fetchedEarly) == .preliminary, "fresh value is marked")
        check(confidence(.partial, fetchedAt: fetchedEarly) == .preliminary, "fresh partial value is marked")
        check(confidence(.preliminary, fetchedAt: fetchedLate) == .measured, "fetched again later loses the mark")
        check(confidence(.measured, fetchedAt: fetchedLate) == .measured, "settled stays settled")
        check(confidence(.partial, fetchedAt: fetchedLate) == .partial, "settled partial keeps partial")
        check(confidence(.measured, fetchedAt: fetchedLate, profile: guessed) == .preliminary, "guessed cost is marked")
        check(confidence(.priceOnly, consumption: false, fetchedAt: fetchedEarly) == .priceOnly, "price rows are not marked")
        check(confidence(.estimated, fetchedAt: fetchedEarly) == .estimated, "estimates are not marked")
        return ok
    }()
}
#endif

/// Remembers that saved history has been priced with `HistoricalTariffRates`.
enum EnergyHistoryTariffSchedule {
    private static let key = "energyHistory.tariffScheduleVersion"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard
    }

    static var needsReprice: Bool {
        (defaults.object(forKey: key) as? Int ?? 0) < HistoricalTariffRates.version
    }

    static func markComplete() {
        guard !DemoMode.isActive else { return }
        defaults.set(HistoricalTariffRates.version, forKey: key)
    }

    // MARK: Agreement versions

    private static let pricedVersionsKey = "energyHistory.pricedCostProfileVersions"

    /// The versions history was last priced with. Nil before the first run.
    static var pricedVersions: [CostProfileVersion]? {
        guard let data = defaults.data(forKey: pricedVersionsKey) else { return nil }
        return CostProfileHistory.decoded(data)
    }

    /// Where history must be priced again for `versions`, or nil when it already matches.
    static func versionRepriceStart(for versions: [CostProfileVersion]) -> Date? {
        HistoryPricing.repriceStart(old: pricedVersions, new: versions)
    }

    static func markPriced(versions: [CostProfileVersion]) {
        guard !DemoMode.isActive, let data = CostProfileHistory.encoded(versions) else { return }
        defaults.set(data, forKey: pricedVersionsKey)
    }

    // MARK: Hours covered by quarters

    private static let overlapCleanupKey = "energyHistory.overlapCleanupVersion"
    private static let overlapCleanupVersion = 1

    /// True until saved history has once been cleared of hours that quarter-hours cover.
    static var needsOverlapCleanup: Bool {
        (defaults.object(forKey: overlapCleanupKey) as? Int ?? 0) < overlapCleanupVersion
    }

    static func markOverlapCleanupComplete() {
        guard !DemoMode.isActive else { return }
        defaults.set(overlapCleanupVersion, forKey: overlapCleanupKey)
    }

    // MARK: Preliminary marks

    private static let preliminaryPassKey = "energyHistory.preliminaryPassVersion"
    private static let preliminaryPassVersion = 1

    /// True until rows saved before preliminary marks existed have been marked once.
    static var needsPreliminaryPass: Bool {
        (defaults.object(forKey: preliminaryPassKey) as? Int ?? 0) < preliminaryPassVersion
    }

    static func markPreliminaryPassComplete() {
        guard !DemoMode.isActive else { return }
        defaults.set(preliminaryPassVersion, forKey: preliminaryPassKey)
    }
}

extension EnhancedCost {
    nonisolated static let zero = EnhancedCost(
        spotCostKr: 0, gridEnergyCostKr: 0, fixedFeeCostKr: 0, powerTariffCostKr: 0,
        energyTaxKr: 0, certificateFeeKr: 0, providerSurchargeKr: 0, providerMonthlyFeeKr: 0, vatKr: 0
    )

    /// Line by line sum, `other` times `scale` (−1 subtracts).
    nonisolated func adding(_ other: EnhancedCost, scale: Double = 1) -> EnhancedCost {
        EnhancedCost(
            spotCostKr: spotCostKr + scale * other.spotCostKr,
            gridEnergyCostKr: gridEnergyCostKr + scale * other.gridEnergyCostKr,
            fixedFeeCostKr: fixedFeeCostKr + scale * other.fixedFeeCostKr,
            powerTariffCostKr: powerTariffCostKr + scale * other.powerTariffCostKr,
            energyTaxKr: energyTaxKr + scale * other.energyTaxKr,
            certificateFeeKr: certificateFeeKr + scale * other.certificateFeeKr,
            providerSurchargeKr: providerSurchargeKr + scale * other.providerSurchargeKr,
            providerMonthlyFeeKr: providerMonthlyFeeKr + scale * other.providerMonthlyFeeKr,
            vatKr: vatKr + scale * other.vatKr
        )
    }
}
