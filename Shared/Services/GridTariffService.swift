//
//  GridTariffService.swift
//  Spotprice
//
//  Service for fetching and managing grid tariff data from Eltariff API
//

import Foundation
import os.log

private let logger = Logger(subsystem: "se.spotprice", category: "GridTariffService")

final class GridTariffService: Sendable {
    private let session: URLSession
    private let baseURL = "https://ri-se.github.io/Eltariff-API/releases/v0.3.1"
    
    // Local presets give immediate coverage for selected DSOs while remote tariff data evolves.
    private let useLocalPresets = true

    // Cached tariff data
    private let cache: TariffCache = TariffCache()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetches all available DSOs and their tariffs
    func fetchAvailableDSOs() async throws -> [DSOOption] {
        if useLocalPresets {
            return getLocalPresetDSOs()
        }
        
        let response = try await fetchAllTariffs()

        // Group by company, filter consumption tariffs
        let consumptionTariffs = response.tariffs.filter { $0.direction == "consumption" }

        var dsoMap: [String: DSOOption] = [:]
        for tariff in consumptionTariffs {
            if dsoMap[tariff.companyOrgNo] == nil {
                dsoMap[tariff.companyOrgNo] = DSOOption(
                    id: tariff.companyOrgNo,
                    name: tariff.companyName,
                    tariffId: tariff.id
                )
            }
        }

        return dsoMap.values.sorted { $0.name < $1.name }
    }

    /// Fetches simplified tariff for a specific DSO
    func fetchTariff(forDSO orgNo: String, fuseSize: Int = 20) async throws -> SimplifiedTariff? {
        let cacheKey = "\(orgNo)_\(fuseSize)"
        
        // Check cache first
        if let cached = await cache.get(cacheKey) {
            logger.info("Returning cached tariff for \(orgNo) @ \(fuseSize)A")
            return cached
        }
        
        if useLocalPresets {
            let tariff = getLocalPresetTariff(forDSO: orgNo, fuseSize: fuseSize)
            if let tariff = tariff {
                await cache.set(tariff, forKey: cacheKey)
            }
            return tariff
        }

        let response = try await fetchAllTariffs()

        // Find first consumption tariff for this DSO
        guard let tariff = response.tariffs.first(where: {
            $0.companyOrgNo == orgNo && $0.direction == "consumption"
        }) else {
            logger.warning("No tariff found for DSO \(orgNo)")
            return nil
        }

        let simplified = simplifyTariff(tariff)
        await cache.set(simplified, forKey: orgNo)

        return simplified
    }

    /// Calculates enhanced cost with tariff breakdown
    func calculateEnhancedCost(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        providerSurcharge: Double = 0,
        providerMonthlyFee: Double = 0,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        let spotCostKr = (spotPriceOre / 100.0) * kWh

        guard let tariff = tariff else {
            // No tariff - use Swedish standard values for taxes
            let providerSurchargeKr = (providerSurcharge / 100.0) * kWh
            let hoursInMonth: Double = 730
            let providerMonthlyFeeKr = (providerMonthlyFee / hoursInMonth) * hoursInPeriod

            // Swedish standard taxes (2025/2026)
            let standardEnergyTax = 54.875  // öre/kWh incl. VAT
            let standardCertificateFee = 1.75  // öre/kWh incl. VAT
            let energyTaxKr = (standardEnergyTax / 100.0) * kWh
            let certificateFeeKr = (standardCertificateFee / 100.0) * kWh

            return EnhancedCost(
                spotCostKr: spotCostKr,
                gridEnergyCostKr: 0,
                fixedFeeCostKr: 0,
                powerTariffCostKr: 0,
                energyTaxKr: energyTaxKr,
                certificateFeeKr: certificateFeeKr,
                providerSurchargeKr: providerSurchargeKr,
                providerMonthlyFeeKr: providerMonthlyFeeKr
            )
        }

        // Grid energy cost
        let gridEnergyCostKr = tariff.energyTariffPerKWh * kWh

        // Pro-rate fixed fee for the time period
        let hoursInMonth: Double = 730 // ~30.4 days × 24h
        let fixedFeeCostKr = (tariff.monthlyFixedFee / hoursInMonth) * hoursInPeriod

        // Power tariff - simplified calculation
        let powerTariffCostKr: Double
        if let powerTariffPerKW = tariff.powerTariffPerKW {
            powerTariffCostKr = (powerTariffPerKW / hoursInMonth) * hoursInPeriod * powerPeakKW
        } else {
            powerTariffCostKr = 0
        }

        // Swedish taxes and fees
        let energyTaxKr = (tariff.energyTaxPerKWh / 100.0) * kWh
        let certificateFeeKr = (tariff.certificateFeePerKWh / 100.0) * kWh

        // Provider costs
        let providerSurchargeKr = (providerSurcharge / 100.0) * kWh
        let providerMonthlyFeeKr = (providerMonthlyFee / hoursInMonth) * hoursInPeriod

        return EnhancedCost(
            spotCostKr: spotCostKr,
            gridEnergyCostKr: gridEnergyCostKr,
            fixedFeeCostKr: fixedFeeCostKr,
            powerTariffCostKr: powerTariffCostKr,
            energyTaxKr: energyTaxKr,
            certificateFeeKr: certificateFeeKr,
            providerSurchargeKr: providerSurchargeKr,
            providerMonthlyFeeKr: providerMonthlyFeeKr
        )
    }

    // MARK: - Local Tariff Presets
    
    private func getLocalPresetDSOs() -> [DSOOption] {
        [
            DSOOption(id: "vaggeryd", name: "Vaggeryds Elnät", tariffId: UUID()),
            DSOOption(id: "jonkoping", name: "Jönköping Energi Elnät", tariffId: UUID()),
            DSOOption(id: "eon", name: "E.ON Energidistribution", tariffId: UUID()),
            DSOOption(id: "vattenfall", name: "Vattenfall Eldistribution", tariffId: UUID()),
            DSOOption(id: "ellevio", name: "Ellevio", tariffId: UUID()),
            DSOOption(id: "goteborg", name: "Göteborg Energi Nät", tariffId: UUID()),
            DSOOption(id: "fortum", name: "Fortum Distribution", tariffId: UUID()),
            DSOOption(id: "skelleftea", name: "Skellefteå Kraft Elnät", tariffId: UUID())
        ]
    }
    
    private func getLocalPresetTariff(forDSO orgNo: String, fuseSize: Int) -> SimplifiedTariff? {
        // Local preset values for 2026 (incl. VAT). User-entered values still win.
        // Fixed fees are monthly, energy is per kWh, power is per kW/month
        
        // Fuse-based tariffs (monthly fixed fee by ampere rating)
        let fuseTariffs: [String: (name: String, fuseFees: [Int: Double], energy: Double, power: Double?, energyTax: Double)] = [
            "vaggeryd": (
                "Vaggeryds Elnät",
                [16: 187.50, 20: 225.00, 25: 270.00, 35: 360.00, 50: 495.00, 63: 612.50],
                0.2813,  // Energy tariff (SEK/kWh)
                45.00,   // Power tariff (SEK/kW/month)
                54.875   // Energy tax 2025
            ),
            "jonkoping": (
                "Jönköping Energi Elnät",
                [16: 328.53, 20: 393.43, 25: 474.36, 35: 636.45, 50: 879.46, 63: 1090.20],
                0.0608,  // Energy tariff (SEK/kWh) - 6.08 öre
                46.68,   // Power tariff average (27.70 base + 65.66 peak) / 2
                45.0     // Energy tax 2026 (reduced)
            ),
            "eon": (
                "E.ON Energidistribution",
                [16: 220.00, 20: 264.00, 25: 318.00, 35: 424.00, 50: 584.00, 63: 722.00],
                0.3250,
                55.00,
                54.875
            ),
            "vattenfall": (
                "Vattenfall Eldistribution",
                [16: 210.00, 20: 252.00, 25: 304.00, 35: 406.00, 50: 560.00, 63: 693.00],
                0.3100,
                52.00,
                54.875
            ),
            "ellevio": (
                "Ellevio",
                [16: 230.00, 20: 276.00, 25: 333.00, 35: 444.00, 50: 612.00, 63: 758.00],
                0.3375,
                58.00,
                54.875
            ),
            "goteborg": (
                "Göteborg Energi Nät",
                [16: 195.00, 20: 234.00, 25: 282.00, 35: 376.00, 50: 518.00, 63: 641.00],
                0.2950,
                48.00,
                54.875
            ),
            "fortum": (
                "Fortum Distribution",
                [16: 215.00, 20: 258.00, 25: 311.00, 35: 415.00, 50: 572.00, 63: 708.00],
                0.3200,
                51.00,
                54.875
            ),
            "skelleftea": (
                "Skellefteå Kraft Elnät",
                [16: 175.00, 20: 210.00, 25: 253.00, 35: 338.00, 50: 466.00, 63: 577.00],
                0.2625,
                42.00,
                54.875
            )
        ]
        
        guard let data = fuseTariffs[orgNo] else { return nil }
        
        // Find the best matching fuse size
        let availableSizes = data.fuseFees.keys.sorted()
        let matchedSize: Int
        
        if data.fuseFees[fuseSize] != nil {
            matchedSize = fuseSize
        } else {
            // Find closest fuse size
            matchedSize = availableSizes.min(by: { abs($0 - fuseSize) < abs($1 - fuseSize) }) ?? 20
        }
        
        let fixedFee = data.fuseFees[matchedSize] ?? data.fuseFees[20] ?? 0
        
        return SimplifiedTariff(
            dsoName: data.name,
            dsoOrgNo: orgNo,
            monthlyFixedFee: fixedFee,
            energyTariffPerKWh: data.energy,
            powerTariffPerKW: data.power,
            validFrom: Date(),
            validTo: nil,
            energyTaxPerKWh: data.energyTax,
            certificateFeePerKWh: 1.75,     // Electricity certificate fee (öre/kWh incl. VAT)
            fuseSize: matchedSize
        )
    }
    
    // MARK: - Private Helpers

    private func fetchAllTariffs() async throws -> TariffsResponse {
        guard let url = URL(string: "\(baseURL)/tariffs") else {
            throw GridTariffError.invalidURL
        }

        logger.info("Fetching tariffs from \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GridTariffError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(TariffsResponse.self, from: data)
        } catch {
            logger.error("Decode error: \(error)")
            throw GridTariffError.decodingError(error)
        }
    }

    private func simplifyTariff(_ tariff: Tariff) -> SimplifiedTariff {
        // Extract monthly fixed fee (sum all fixed price components)
        let monthlyFixedFee = tariff.fixedPrice.components
            .filter { $0.pricedPeriod.contains("M") } // monthly period
            .reduce(0.0) { $0 + $1.price.priceIncVat }

        // Extract energy tariff (average of all energy components)
        let energyComponents = tariff.energyPrice.components
            .filter { $0.type == "fixed" }
            .compactMap { $0.price?.priceIncVat }
        let energyTariffPerKWh = energyComponents.isEmpty ? 0.0 :
            energyComponents.reduce(0.0, +) / Double(energyComponents.count)

        // Extract power tariff if available
        let powerComponents = tariff.powerPrice.components
            .filter { $0.type == "peak" }
            .compactMap { $0.price?.priceIncVat }
        let powerTariffPerKW = powerComponents.first

        let validFrom = ISO8601DateFormatter().date(from: tariff.validPeriod.fromIncluding) ?? Date()
        let validTo = tariff.validPeriod.toExcluding.flatMap {
            ISO8601DateFormatter().date(from: $0)
        }

        return SimplifiedTariff(
            dsoName: tariff.companyName,
            dsoOrgNo: tariff.companyOrgNo,
            monthlyFixedFee: monthlyFixedFee,
            energyTariffPerKWh: energyTariffPerKWh,
            powerTariffPerKW: powerTariffPerKW,
            validFrom: validFrom,
            validTo: validTo,
            energyTaxPerKWh: 54.875,        // Swedish energy tax 2025 (öre/kWh incl. VAT)
            certificateFeePerKWh: 1.75,     // Electricity certificate fee (öre/kWh incl. VAT)
            fuseSize: nil                   // Unknown for API tariffs
        )
    }
}

// MARK: - Cache

private actor TariffCache {
    private var cache: [String: CachedTariff] = [:]
    private let maxAge: TimeInterval = 3600 * 24 // 24 hours

    struct CachedTariff {
        let tariff: SimplifiedTariff
        let timestamp: Date
    }

    func get(_ key: String) -> SimplifiedTariff? {
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < maxAge else {
            return nil
        }
        return cached.tariff
    }

    func set(_ tariff: SimplifiedTariff, forKey key: String) {
        cache[key] = CachedTariff(tariff: tariff, timestamp: Date())
    }
}

// MARK: - Errors

enum GridTariffError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Kunde inte skapa URL för Eltariff API"
        case .invalidResponse:
            return "Fel svar från Eltariff API"
        case .decodingError:
            return "Kunde inte läsa tariffdata från servern."
        case .notFound:
            return "Hittade ingen tariff för vald nätoperatör"
        }
    }
}
