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
    
    // Use mock data until individual DSOs implement the Eltariff API
    private let useMockData = true

    // Cached tariff data
    private let cache: TariffCache = TariffCache()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetches all available DSOs and their tariffs
    func fetchAvailableDSOs() async throws -> [DSOOption] {
        if useMockData {
            return getMockDSOs()
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
    func fetchTariff(forDSO orgNo: String) async throws -> SimplifiedTariff? {
        // Check cache first
        if let cached = await cache.get(orgNo) {
            logger.info("Returning cached tariff for \(orgNo)")
            return cached
        }
        
        if useMockData {
            let tariff = getMockTariff(forDSO: orgNo)
            if let tariff = tariff {
                await cache.set(tariff, forKey: orgNo)
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
        settings: ConsumptionSettings = .shared,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        let spotCostKr = (spotPriceOre / 100.0) * kWh

        guard let tariff = tariff else {
            // No tariff - only spot price and provider costs
            let providerSurchargeKr = (settings.providerSurchargePerKWh / 100.0) * kWh
            let hoursInMonth: Double = 730
            let providerMonthlyFeeKr = (settings.providerMonthlyFee / hoursInMonth) * hoursInPeriod
            
            return EnhancedCost(
                spotCostKr: spotCostKr,
                gridEnergyCostKr: 0,
                fixedFeeCostKr: 0,
                powerTariffCostKr: 0,
                energyTaxKr: 0,
                certificateFeeKr: 0,
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
        let providerSurchargeKr = (settings.providerSurchargePerKWh / 100.0) * kWh
        let providerMonthlyFeeKr = (settings.providerMonthlyFee / hoursInMonth) * hoursInPeriod

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

    // MARK: - Mock Data (Temporary until DSOs implement Eltariff API)
    
    private func getMockDSOs() -> [DSOOption] {
        [
            DSOOption(id: "vaggeryd", name: "Vaggeryds Elnät", tariffId: UUID()),
            DSOOption(id: "eon", name: "E.ON Energidistribution", tariffId: UUID()),
            DSOOption(id: "vattenfall", name: "Vattenfall Eldistribution", tariffId: UUID()),
            DSOOption(id: "ellevio", name: "Ellevio", tariffId: UUID()),
            DSOOption(id: "goteborg", name: "Göteborg Energi Nät", tariffId: UUID()),
            DSOOption(id: "fortum", name: "Fortum Distribution", tariffId: UUID()),
            DSOOption(id: "skelleftea", name: "Skellefteå Kraft Elnät", tariffId: UUID())
        ]
    }
    
    private func getMockTariff(forDSO orgNo: String) -> SimplifiedTariff? {
        // Realistic Swedish grid tariff values for 2025 (incl. VAT)
        // Based on typical residential tariffs from major Swedish DSOs
        // Fixed fees are monthly, energy is per kWh, power is per kW/month
        let mockTariffs: [String: (name: String, fixed: Double, energy: Double, power: Double?)] = [
            "vaggeryd": ("Vaggeryds Elnät", 187.50, 0.2813, 45.00),      // Small local DSO
            "eon": ("E.ON Energidistribution", 220.00, 0.3250, 55.00),   // Major national DSO
            "vattenfall": ("Vattenfall Eldistribution", 210.00, 0.3100, 52.00), // Major national DSO
            "ellevio": ("Ellevio", 230.00, 0.3375, 58.00),               // Largest DSO in Sweden
            "goteborg": ("Göteborg Energi Nät", 195.00, 0.2950, 48.00),  // Municipal DSO
            "fortum": ("Fortum Distribution", 215.00, 0.3200, 51.00),    // Nordic energy company
            "skelleftea": ("Skellefteå Kraft Elnät", 175.00, 0.2625, 42.00) // Northern Sweden
        ]
        
        guard let data = mockTariffs[orgNo] else { return nil }
        
        // Note: These are realistic averages. Actual tariffs vary by:
        // - Time of use (day/night rates)
        // - Season (winter/summer)
        // - Fuse size/subscription level
        // - Geographic location
        
        return SimplifiedTariff(
            dsoName: data.name,
            dsoOrgNo: orgNo,
            monthlyFixedFee: data.fixed,
            energyTariffPerKWh: data.energy,
            powerTariffPerKW: data.power,
            validFrom: Date(),
            validTo: nil,
            energyTaxPerKWh: 54.875,        // Swedish energy tax 2025 (öre/kWh incl. VAT)
            certificateFeePerKWh: 1.75      // Electricity certificate fee (öre/kWh incl. VAT)
        )
    }
    
    // MARK: - Private Helpers

    private func fetchAllTariffs() async throws -> TariffsResponse {
        let url = URL(string: "\(baseURL)/tariffs")!

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
            certificateFeePerKWh: 1.75      // Electricity certificate fee (öre/kWh incl. VAT)
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
    case invalidResponse
    case decodingError(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Fel svar från Eltariff API"
        case .decodingError(let error):
            return "Kunde inte läsa tariffdata: \(error.localizedDescription)"
        case .notFound:
            return "Hittade ingen tariff för vald nätoperatör"
        }
    }
}
