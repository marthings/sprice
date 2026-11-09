//
//  CostProfile.swift
//  Spotprice
//
//  Central user-facing cost profile for estimated and configured electricity costs.
//

import Foundation

// MARK: - Cost Profile

struct CostProfile: Codable, Equatable, Sendable {
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
    enum SwedishDefaults {
        static let priceArea = "SE3"
        static let retailerMarkupOrePerKWh = 4.0
        static let retailerMonthlyFee = 0.0
        static let energyTaxOrePerKWh = 54.875
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

    func updating(
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

enum RetailContractType: String, Codable, Equatable, Sendable {
    case spotPriceMarkup
    case variableMonthlyPrice
    case fixedPrice
}

// MARK: - Confidence

enum CostConfidence: String, Codable, Equatable, Sendable {
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

enum TariffSource: String, Codable, Equatable, Sendable {
    case defaultEstimate
    case userEntered
    case localPreset
    case remoteTariff
    case providerData
}

// MARK: - Effect Tariff

struct EffectTariff: Codable, Equatable, Sendable {
    let monthlyPricePerKW: Double
    let model: EffectTariffModel
    let activeHours: EffectTariffActiveHours
}

enum EffectTariffModel: String, Codable, Equatable, Sendable {
    case singlePeak
    case averageTopThree
    case averageTopFive
    case manual
}

enum EffectTariffActiveHours: String, Codable, Equatable, Sendable {
    case allHours
    case weekdaysDaytime
    case custom
}
