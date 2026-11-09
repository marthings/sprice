//
//  GridTariffModels.swift
//  Spotprice
//
//  Grid tariff data models for Eltariff API integration
//

import Foundation

// MARK: - API Response Models

struct TariffsResponse: Decodable, Sendable {
    let tariffs: [Tariff]
    let calendarPatterns: [CalendarPattern]
}

struct Tariff: Identifiable, Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let validPeriod: DateInterval
    let timeZone: String
    let lastUpdated: Date
    let companyName: String
    let companyOrgNo: String
    let product: String
    let direction: String
    let billingPeriod: String
    let fixedPrice: FixedPrice
    let energyPrice: EnergyPrice
    let powerPrice: PowerPrice
}

struct FixedPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [FixedPriceComponent]
}

struct FixedPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price
    let pricedPeriod: String
}

struct EnergyPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [EnergyPriceComponent]
}

struct EnergyPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price?
    let unit: String
    let spotPriceSettings: SpotPriceSettings?
    let recurringPeriods: [RecurringPeriod]?
}

struct PowerPrice: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let costFunction: String
    let components: [PowerPriceComponent]
}

struct PowerPriceComponent: Decodable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let type: String
    let reference: String
    let validPeriod: DateInterval
    let price: Price?
    let unit: String
    let url: String?
}

struct Price: Decodable, Sendable {
    let priceExVat: Double
    let priceIncVat: Double
    let currency: String
}

struct SpotPriceSettings: Decodable, Sendable {
    let multiplier: Double
    let currency: String
}

struct RecurringPeriod: Decodable, Sendable {
    let reference: String
    let frequency: String
    let activePeriods: [ActivePeriod]
}

struct ActivePeriod: Decodable, Sendable {
    let fromIncluding: String
    let toExcluding: String
    let calendarPatternReferences: CalendarPatternReferences?
}

struct CalendarPatternReferences: Decodable, Sendable {
    let include: [String]?
    let exclude: [String]?
}

struct CalendarPattern: Decodable, Sendable {
    let reference: String
    let frequency: String
    let days: [Int]?
    let dates: [String]?
}

struct DateInterval: Decodable, Sendable {
    let fromIncluding: String
    let toExcluding: String?
}

// MARK: - Simplified User-Facing Models

/// Simplified tariff for cost calculations
struct SimplifiedTariff: Equatable, Sendable, Codable {
    let dsoName: String
    let dsoOrgNo: String
    let monthlyFixedFee: Double        // SEK incl. VAT
    let energyTariffPerKWh: Double     // SEK incl. VAT
    let powerTariffPerKW: Double?      // SEK incl. VAT per month
    let validFrom: Date
    let validTo: Date?
    
    // Swedish taxes and fees (hardcoded standard values 2025)
    let energyTaxPerKWh: Double        // Energiskatt öre/kWh incl. VAT (54.875)
    let certificateFeePerKWh: Double   // Elcertifikat öre/kWh incl. VAT (1.75)
    
    // Fuse size this tariff is for (in amperes)
    let fuseSize: Int?
}

/// Multiple tariff options for different fuse sizes
struct FusedTariffs: Sendable {
    let dsoName: String
    let dsoOrgNo: String
    let tariffsByFuseSize: [Int: SimplifiedTariff]  // [fuseSize: tariff]
    
    /// Get tariff for specific fuse size, or closest match
    func tariff(forFuseSize fuseSize: Int) -> SimplifiedTariff? {
        // Try exact match first
        if let exact = tariffsByFuseSize[fuseSize] {
            return exact
        }
        
        // Find closest fuse size
        let sortedSizes = tariffsByFuseSize.keys.sorted()
        guard let smallestSize = sortedSizes.first,
              let largestSize = sortedSizes.last else {
            return nil
        }
        
        // If requested size is smaller than smallest, use smallest
        if fuseSize < smallestSize {
            return tariffsByFuseSize[smallestSize]
        }
        
        // If requested size is larger than largest, use largest
        if fuseSize > largestSize {
            return tariffsByFuseSize[largestSize]
        }
        
        // Find closest match
        var closest = smallestSize
        var minDiff = abs(fuseSize - closest)
        
        for size in sortedSizes {
            let diff = abs(fuseSize - size)
            if diff < minDiff {
                minDiff = diff
                closest = size
            }
        }
        
        return tariffsByFuseSize[closest]
    }
    
    /// Common fuse sizes available
    var availableFuseSizes: [Int] {
        tariffsByFuseSize.keys.sorted()
    }
}

/// DSO metadata for picker
struct DSOOption: Identifiable, Sendable {
    let id: String         // companyOrgNo
    let name: String       // companyName
    let tariffId: UUID     // for fetching specific tariff
}

// MARK: - Enhanced Cost Models

nonisolated struct EnhancedCost: Sendable {
    /// Retail energy (spot or contract), excluding VAT.
    let spotCostKr: Double
    /// Grid transfer, excluding VAT.
    let gridEnergyCostKr: Double
    /// Grid monthly fee share, excluding VAT.
    let fixedFeeCostKr: Double
    /// Power tariff share, excluding VAT.
    let powerTariffCostKr: Double
    /// Energy tax, excluding VAT.
    let energyTaxKr: Double
    /// Electricity certificate fee, excluding VAT.
    let certificateFeeKr: Double
    /// Supplier markup, excluding VAT.
    let providerSurchargeKr: Double
    /// Retailer monthly fee share, excluding VAT.
    let providerMonthlyFeeKr: Double
    /// VAT on the sum of the lines above.
    let vatKr: Double

    var totalExcludingVATKr: Double {
        spotCostKr + gridEnergyCostKr + fixedFeeCostKr +
        powerTariffCostKr + energyTaxKr + certificateFeeKr +
        providerSurchargeKr + providerMonthlyFeeKr
    }

    /// What a Swedish consumer pays, including VAT.
    var totalKr: Double {
        totalExcludingVATKr + vatKr
    }

    var gridTotalKr: Double {
        gridEnergyCostKr + fixedFeeCostKr + powerTariffCostKr
    }

    var taxesAndFeesKr: Double {
        energyTaxKr + certificateFeeKr
    }

    var providerTotalKr: Double {
        spotCostKr + providerSurchargeKr + providerMonthlyFeeKr
    }

    /// Spot from the market is excluding VAT. Every other stored profile/tariff
    /// amount is consumer-facing including VAT. This strips VAT from those
    /// amounts, then adds one VAT line so the total matches the invoice.
    static func assembling(
        spotExcludingVAT: Double,
        gridEnergyIncludingVAT: Double,
        fixedFeeIncludingVAT: Double,
        powerTariffIncludingVAT: Double,
        energyTaxIncludingVAT: Double,
        certificateFeeIncludingVAT: Double,
        surchargeIncludingVAT: Double,
        monthlyFeeIncludingVAT: Double,
        vatRate: Double
    ) -> EnhancedCost {
        let gridEnergy = ElectricityCostMath.excludingVAT(gridEnergyIncludingVAT, vatRate: vatRate)
        let fixedFee = ElectricityCostMath.excludingVAT(fixedFeeIncludingVAT, vatRate: vatRate)
        let powerTariff = ElectricityCostMath.excludingVAT(powerTariffIncludingVAT, vatRate: vatRate)
        let energyTax = ElectricityCostMath.excludingVAT(energyTaxIncludingVAT, vatRate: vatRate)
        let certificate = ElectricityCostMath.excludingVAT(certificateFeeIncludingVAT, vatRate: vatRate)
        let surcharge = ElectricityCostMath.excludingVAT(surchargeIncludingVAT, vatRate: vatRate)
        let monthlyFee = ElectricityCostMath.excludingVAT(monthlyFeeIncludingVAT, vatRate: vatRate)

        let excludingVAT = spotExcludingVAT + gridEnergy + fixedFee + powerTariff +
            energyTax + certificate + surcharge + monthlyFee

        return EnhancedCost(
            spotCostKr: spotExcludingVAT,
            gridEnergyCostKr: gridEnergy,
            fixedFeeCostKr: fixedFee,
            powerTariffCostKr: powerTariff,
            energyTaxKr: energyTax,
            certificateFeeKr: certificate,
            providerSurchargeKr: surcharge,
            providerMonthlyFeeKr: monthlyFee,
            vatKr: ElectricityCostMath.vat(onExcludingVAT: excludingVAT, vatRate: vatRate)
        )
    }
}

// MARK: - VAT

nonisolated enum ElectricityCostMath {
    nonisolated static let standardVATRate = CostProfile.SwedishDefaults.vatRate

    /// Profile values (markup, grid, tax, certificates, monthly fees) are stored including VAT.
    static func excludingVAT(_ amountIncludingVAT: Double, vatRate: Double = standardVATRate) -> Double {
        let divisor = 1 + vatRate
        guard divisor > 0 else { return amountIncludingVAT }
        return amountIncludingVAT / divisor
    }

    static func vat(onExcludingVAT amount: Double, vatRate: Double = standardVATRate) -> Double {
        amount * vatRate
    }

    static func includingVAT(_ amountExcludingVAT: Double, vatRate: Double = standardVATRate) -> Double {
        amountExcludingVAT * (1 + vatRate)
    }

    /// Worked example: SE3 spot 50 öre excluding VAT, 4 öre markup including VAT,
    /// Jönköping 20 A grid preset.
    ///
    /// Excluding VAT, öre/kWh for 1 kWh during 1 hour:
    /// spot 50.00, markup 3.20, grid transfer 4.864, energy tax 36.00,
    /// certificate 1.40, grid monthly share 43.115616, VAT 34.644904.
    /// Total 1.732245 kr/kWh including VAT.
    static func workedExampleSE3Jonkoping20A() -> CostProfile {
        CostProfile(
            priceArea: "SE3",
            retailContractType: .spotPriceMarkup,
            retailerMarkupOrePerKWh: 4.0,
            contractPriceOrePerKWh: nil,
            retailerMonthlyFee: 0,
            retailContractSource: .defaultEstimate,
            gridCompanyId: "jonkoping",
            gridCompanyName: "Jönköping Energi Elnät",
            fuseSize: 20,
            gridMonthlyFee: 393.43,
            gridTransferOrePerKWh: 6.08,
            gridCostSource: .localPreset,
            energyTaxOrePerKWh: 45.0,
            certificateFeeOrePerKWh: 1.75,
            vatRate: standardVATRate,
            effectTariff: nil,
            confidence: .userConfigured,
            source: .localPreset,
            tariffLastUpdated: nil,
            tariffValidUntil: nil
        )
    }

    static let workedExampleSpotOre = 50.0
    static let workedExampleExpectedTotalKr = 1.7322452054794522
}

// MARK: - Provider Cost Information Models

/// Cost information from electricity provider API
struct ProviderCostInfo: Sendable {
    /// Spot price in öre/kWh (energy component)
    let spotPriceOre: Double?

    /// Provider surcharge in öre/kWh (påslag)
    let surchargePerKWh: Double?

    /// Monthly subscription fee in SEK
    let monthlyFee: Double?

    /// Energy tax in öre/kWh (energiskatt)
    let energyTaxPerKWh: Double?

    /// Certificate fee in öre/kWh (elcertifikat)
    let certificateFeePerKWh: Double?

    /// Total price in öre/kWh (if provider gives complete price)
    let totalPriceOre: Double?

    /// Timestamp when this data was fetched
    let timestamp: Date

    /// Whether this data is from real-time API or cached
    let isRealTime: Bool

    init(
        spotPriceOre: Double? = nil,
        surchargePerKWh: Double? = nil,
        monthlyFee: Double? = nil,
        energyTaxPerKWh: Double? = nil,
        certificateFeePerKWh: Double? = nil,
        totalPriceOre: Double? = nil,
        timestamp: Date = Date(),
        isRealTime: Bool = true
    ) {
        self.spotPriceOre = spotPriceOre
        self.surchargePerKWh = surchargePerKWh
        self.monthlyFee = monthlyFee
        self.energyTaxPerKWh = energyTaxPerKWh
        self.certificateFeePerKWh = certificateFeePerKWh
        self.totalPriceOre = totalPriceOre
        self.timestamp = timestamp
        self.isRealTime = isRealTime
    }
}

/// Provider cost capabilities - describes what each provider supports
enum ProviderCostCapability {
    case automatic      // Fetches from API automatically
    case defaults       // Has hardcoded defaults
    case manual         // User must configure manually
}

/// Provider cost metadata - UI hints and descriptions per provider
struct ProviderCostMetadata: Sendable {
    let capability: ProviderCostCapability
    let badgeText: String?
    let badgeIcon: String?
    let badgeColor: String  // "green", "blue", "gray"
    let surchargeHint: String?
    let monthlyFeeHint: String?
    let helpText: String
    
    static func forProvider(_ providerId: String) -> ProviderCostMetadata {
        switch providerId {
        case "tibber":
            return ProviderCostMetadata(
                capability: .automatic,
                badgeText: "Automatisk för Tibber",
                badgeIcon: "checkmark.circle.fill",
                badgeColor: "green",
                surchargeHint: "Tibber default: 8,75 öre",
                monthlyFeeHint: "Tibber default: 49 kr",
                helpText: "Tibber-kunder får automatiska kostnader från API. Du kan ange egna värden om du vill åsidosätta."
            )
        case "vaggeryd":
            return ProviderCostMetadata(
                capability: .defaults,
                badgeText: "Defaults tillgängliga",
                badgeIcon: "info.circle.fill",
                badgeColor: "blue",
                surchargeHint: "Vaggeryd default: 6 öre",
                monthlyFeeHint: "Vaggeryd default: 39 kr",
                helpText: "Uppskattade defaults används om du lämnar 0. Ange exakta värden från ditt avtal för bästa precision."
            )
        default:
            return ProviderCostMetadata(
                capability: .manual,
                badgeText: nil,
                badgeIcon: nil,
                badgeColor: "gray",
                surchargeHint: nil,
                monthlyFeeHint: nil,
                helpText: "Ange elhandelsavgifter och månadsavgift från ditt avtal. Dessa läggs till kvartspriset."
            )
        }
    }
}

/// Provider defaults - hardcoded fallback values for common providers
enum ProviderDefaults {
    /// Tibber default values (2025)
    static let tibber = ProviderCostInfo(
        surchargePerKWh: 8.75,        // ~8.75 öre/kWh påslag
        monthlyFee: 49.0,              // 49 kr/mån
        energyTaxPerKWh: 54.875,       // Standard svensk energiskatt
        certificateFeePerKWh: 1.75,    // Genomsnittlig elcertifikatavgift
        isRealTime: false
    )
    
    /// Vaggeryd Energi default values (2025)
    /// Note: Vaggeryd only provides consumption data, not pricing
    /// These are typical values for their spot price contracts
    static let vaggeryd = ProviderCostInfo(
        surchargePerKWh: 6.0,          // ~6 öre/kWh påslag (estimated)
        monthlyFee: 39.0,              // 39 kr/mån (estimated)
        energyTaxPerKWh: 54.875,       // Standard svensk energiskatt
        certificateFeePerKWh: 1.75,    // Genomsnittlig elcertifikatavgift
        isRealTime: false
    )

    /// Generic Swedish provider defaults
    static let generic = ProviderCostInfo(
        surchargePerKWh: 0.0,          // User must configure
        monthlyFee: 0.0,               // User must configure
        energyTaxPerKWh: 54.875,       // Standard svensk energiskatt
        certificateFeePerKWh: 1.75,    // Genomsnittlig elcertifikatavgift
        isRealTime: false
    )
    
    /// Get default for a specific provider ID
    static func forProvider(_ providerId: String) -> ProviderCostInfo {
        switch providerId {
        case "tibber":
            return tibber
        case "vaggeryd":
            return vaggeryd
        default:
            return generic
        }
    }
}

/// Daily price information with all cost components
struct DailyProviderPrices: Sendable {
    let date: Date
    let hourlyPrices: [HourlyProviderPrice]
}

/// Hourly price with complete breakdown
struct HourlyProviderPrice: Sendable {
    let startsAt: Date
    let endsAt: Date
    let spotPriceOre: Double
    let totalPriceOre: Double      // Includes everything
    let energyPriceOre: Double?    // Just energy (spot)
    let taxOre: Double?            // Taxes (energy + certificate)

    /// Calculated surcharge (total - energy - tax)
    var calculatedSurchargeOre: Double? {
        guard let energy = energyPriceOre, let tax = taxOre else { return nil }
        return totalPriceOre - energy - tax
    }
}
