//
//  CostProfile.swift
//  Spotprice
//
//  Central user-facing cost profile for estimated and configured electricity costs.
//

import Foundation

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
        static let energyTaxOrePerKWh = 45.0
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

// MARK: - Rates by date

/// The fees that were in force on a given date.
///
/// History must be priced with the rates of its own period. A frozen copy of
/// "today's" profile makes October 2026 look cheaper than November just because
/// the profile was refreshed in between. Two eras are known:
/// - up to and including 2025: energy tax 54,875 öre and the old Vaggeryds Energi grid fees
/// - from 2026-01-01: energy tax 45 öre and the 2026 grid fees
///
/// Only values that exactly match a known preset are swapped. A value the user
/// typed in themselves is left alone.
nonisolated enum HistoricalTariffRates {
    /// Bump when the table below changes, so saved history is priced again once.
    static let version = 1

    static let energyTax2025InclVAT = 54.875
    static let energyTax2026InclVAT = 45.0
    static let vaggerydTransfer2025OrePerKWh = 28.13
    static let vaggerydTransfer2026OrePerKWh = 29.75
    static let vaggerydPowerTariff2025KrPerKW = 45.0
    static let vaggerydMonthlyFees2025: [Int: Double] = [
        16: 187.50, 20: 225.00, 25: 270.00, 35: 360.00, 50: 495.00, 63: 612.50
    ]
    static let vaggerydMonthlyFees2026: [Int: Double] = [
        16: 458, 20: 742, 25: 975, 35: 1_233, 50: 1_967, 63: 2_475
    ]

    /// 2026-01-01 00:00 in Swedish time.
    static var year2026Start: Date {
        Calendar.energyHistory.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantFuture
    }

    static func isFrom2026(_ date: Date) -> Bool {
        date >= year2026Start
    }

    /// `profile` with the fees that applied on `date`.
    static func profile(_ profile: CostProfile, forPeriodStarting date: Date) -> CostProfile {
        let from2026 = isFrom2026(date)
        var tax: Double?
        var fee: Double?
        var transfer: Double?

        let (oldTax, newTax) = from2026
            ? (energyTax2025InclVAT, energyTax2026InclVAT)
            : (energyTax2026InclVAT, energyTax2025InclVAT)
        if abs(profile.energyTaxOrePerKWh - oldTax) < 0.001 {
            tax = newTax
        }

        if (profile.gridCompanyId ?? "") == "vaggeryd" {
            let (fromFees, toFees) = from2026
                ? (vaggerydMonthlyFees2025, vaggerydMonthlyFees2026)
                : (vaggerydMonthlyFees2026, vaggerydMonthlyFees2025)
            if let current = profile.gridMonthlyFee,
               let fuse = fromFees.first(where: { abs($0.value - current) < 0.01 })?.key,
               let replacement = toFees[fuse] {
                fee = replacement
            }
            let (oldTransfer, newTransfer) = from2026
                ? (vaggerydTransfer2025OrePerKWh, vaggerydTransfer2026OrePerKWh)
                : (vaggerydTransfer2026OrePerKWh, vaggerydTransfer2025OrePerKWh)
            if let current = profile.gridTransferOrePerKWh, abs(current - oldTransfer) < 0.01 {
                transfer = newTransfer
            }
        }

        guard tax != nil || fee != nil || transfer != nil else { return profile }
        return profile.updating(
            gridMonthlyFee: fee,
            gridTransferOrePerKWh: transfer,
            energyTaxOrePerKWh: tax
        )
    }
}

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
}
