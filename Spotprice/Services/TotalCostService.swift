//
//  TotalCostService.swift
//  Spotprice
//
//  Centralized service for total cost calculations including all components
//

import Foundation

final class TotalCostService: Sendable {
    private let gridTariffService: GridTariffService
    private let consumptionService: ConsumptionService

    init(gridTariffService: GridTariffService = GridTariffService(),
         consumptionService: ConsumptionService = ConsumptionService()) {
        self.gridTariffService = gridTariffService
        self.consumptionService = consumptionService
    }

    /// Calculate total cost for a given consumption
    /// Uses provider defaults if settings values are 0
    func calculateTotalCost(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        // Get effective values (use provider defaults if settings are 0)
        let defaults = ProviderDefaults.forProvider(settings.selectedProviderId)
        let effectiveSurcharge = settings.providerSurchargePerKWh > 0 
            ? settings.providerSurchargePerKWh 
            : (defaults.surchargePerKWh ?? 0)
        let effectiveMonthlyFee = settings.providerMonthlyFee > 0 
            ? settings.providerMonthlyFee 
            : (defaults.monthlyFee ?? 0)
        
        return gridTariffService.calculateEnhancedCost(
            kWh: kWh,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings,
            powerPeakKW: powerPeakKW,
            hoursInPeriod: hoursInPeriod,
            providerSurchargeOverride: effectiveSurcharge,
            providerMonthlyFeeOverride: effectiveMonthlyFee
        )
    }

    /// Calculate total price per kWh (all components included)
    func calculatePricePerKWh(
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared
    ) -> Double {
        let cost = calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings,
            hoursInPeriod: 1.0
        )
        return cost.totalKr  // kr/kWh
    }
    
    /// Format total price per kWh for display
    func formattedPricePerKWh(
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        settings: ConsumptionSettings = .shared
    ) -> String {
        let priceKr = calculatePricePerKWh(
            spotPriceOre: spotPriceOre,
            tariff: tariff,
            settings: settings
        )
        return String(format: "%.2f", priceKr)
    }
    
    // MARK: - Provider-Enhanced Calculations
    
    /// Fetch current provider cost info from API
    /// Returns provider cost data if available, nil otherwise
    func fetchProviderCosts(settings: ConsumptionSettings = .shared) async -> ProviderCostInfo? {
        // Check if user has a provider configured
        guard !settings.selectedProviderId.isEmpty else {
            return nil
        }
        
        // Get provider credentials
        let credentials = settings.getCredentials(for: settings.selectedProviderId)
        
        // Try to get provider instance from registry
        guard let providerInstance = ProviderRegistry.shared.createProvider(
            identifier: settings.selectedProviderId,
            credentials: credentials
        ) else {
            return nil
        }
        
        // Check if provider supports price info
        guard let priceProvider = providerInstance as? PriceInfoProvider else {
            // Provider doesn't support price info
            return nil
        }
        
        // Fetch current price info from provider API
        do {
            let providerCost = try await priceProvider.fetchCurrentPriceInfo()
            return providerCost
        } catch {
            // API failed, return provider defaults
            return type(of: priceProvider).defaultCostInfo
        }
    }
    
    /// Calculate total cost using provider data if available, otherwise use settings
    func calculateTotalCostWithProvider(
        kWh: Double,
        spotPriceOre: Double,
        tariff: SimplifiedTariff?,
        providerCost: ProviderCostInfo?,
        settings: ConsumptionSettings = .shared,
        powerPeakKW: Double = 0,
        hoursInPeriod: Double = 1.0
    ) -> EnhancedCost {
        // Use provider data if available and recent (less than 15 minutes old)
        let useProviderData = providerCost.map { cost in
            cost.isRealTime && Date().timeIntervalSince(cost.timestamp) < 900
        } ?? false
        
        if useProviderData, let providerCost = providerCost {
            // Use provider surcharge if available, otherwise fall back to settings
            let surcharge = providerCost.surchargePerKWh ?? settings.providerSurchargePerKWh
            let monthlyFee = providerCost.monthlyFee ?? settings.providerMonthlyFee
            
            // Create temporary settings with provider values
            let effectiveSettings = ConsumptionSettings.shared
            // Note: We can't modify shared settings here, so we'll use provider values directly
            
            return gridTariffService.calculateEnhancedCost(
                kWh: kWh,
                spotPriceOre: spotPriceOre,
                tariff: tariff,
                settings: settings,
                powerPeakKW: powerPeakKW,
                hoursInPeriod: hoursInPeriod,
                providerSurchargeOverride: surcharge,
                providerMonthlyFeeOverride: monthlyFee
            )
        } else {
            // Use settings as before
            return calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spotPriceOre,
                tariff: tariff,
                settings: settings,
                powerPeakKW: powerPeakKW,
                hoursInPeriod: hoursInPeriod
            )
        }
    }
}
