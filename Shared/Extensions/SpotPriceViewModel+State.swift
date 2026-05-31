//
//  SpotPriceViewModel+State.swift
//  Spotprice
//

import SwiftUI
import OSLog

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay + " öre"
        }
        return "--"
    }
    
    /// Total price per kWh including all components (spot + grid + taxes + provider)
    @MainActor
    func totalPriceLabel() -> String {
        guard case .loaded(let payload) = self,
              let currentBucket = payload.day.currentBucket else {
            return "--"
        }

        let service = TotalCostService()
        let profile = ConsumptionSettings.shared.costProfile
        let totalPriceKr = service.calculatePricePerKWh(
            spotPriceOre: currentBucket.orePerKWh,
            profile: profile
        )

        AppLog.menuBar.debug("Current spot \(currentBucket.orePerKWh, privacy: .public) öre, total \(totalPriceKr, privacy: .public) kr/kWh")
        AppLog.menuBar.debug("Bucket interval \(currentBucket.start, privacy: .public)-\(currentBucket.end, privacy: .public)")
        AppLog.menuBar.debug("Profile markup \(profile.retailerMarkupOrePerKWh, privacy: .public), contract \(profile.retailContractType.rawValue, privacy: .public), contract price \(profile.contractPriceOrePerKWh ?? 0, privacy: .public)")

        return "\(totalPriceKr.formatted(.number.precision(.fractionLength(2)))) kr/kWh"
    }

    var labelColor: Color {
        if case .loaded(let payload) = self {
            if let bucket = payload.day.currentBucket {
                return DS.Color.forPrice(bucket.orePerKWh, min: payload.day.minOre, max: payload.day.maxOre)
            }
        }
        return DS.Color.secondary
    }

    var currentCategory: PriceCategory? {
        if case .loaded(let payload) = self {
            if let bucket = payload.day.currentBucket {
                return DS.Color.categoryForPrice(bucket.orePerKWh, min: payload.day.minOre, max: payload.day.maxOre)
            }
        }
        return nil
    }

    /// Returns (current, next) prices for trend indicator
    var trendPrices: (current: Double, next: Double)? {
        guard case .loaded(let payload) = self else { return nil }

        let now = Date.now
        guard let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) else {
            return nil
        }

        // Find next bucket
        let nextBucket = payload.day.buckets.first { $0.start >= currentBucket.end }

        if let next = nextBucket {
            return (currentBucket.orePerKWh, next.orePerKWh)
        }
        return nil
    }
}
