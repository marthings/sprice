//
//  SpotPriceViewModel+State.swift
//  Spotprice
//

import SwiftUI

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay + " öre"
        }
        return "--"
    }

    var labelColor: Color {
        if case .loaded(let payload) = self {
            if let bucket = payload.day.currentBucket {
                return DS.Color.forPrice(bucket.orePerKWh, min: payload.day.minOre, max: payload.day.maxOre)
            }
        }
        return .secondary
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

        let now = Date()
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

extension SummaryViewModel.State {
    var isLoading: Bool {
        switch self {
        case .loadingConsumption, .analyzing:
            return true
        default:
            return false
        }
    }
}
