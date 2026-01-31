//
//  SpotPriceViewModel+State.swift
//  Spotprice
//

import SwiftUI

extension SpotPriceViewModel.State {
    var currentPriceLabel: String {
        if case .loaded(let payload) = self {
            return payload.currentDisplay
        }
        return "--"
    }

    var labelColor: Color {
        if case .loaded(let payload) = self {
            // Use current hour index to match the chart exactly
            let currentHour = Calendar.current.component(.hour, from: Date())
            let prices = payload.day.buckets.map { $0.orePerKWh }

            if currentHour >= 0 && currentHour < prices.count {
                let priceAtCurrentHour = prices[currentHour]
                return DS.Color.forPrice(priceAtCurrentHour, min: payload.day.minOre, max: payload.day.maxOre)
            }
        }
        return .secondary
    }
}

extension SummaryViewModel.State {
    var isLoading: Bool {
        switch self {
        case .loadingURL, .fetchingReport, .summarizing:
            return true
        default:
            return false
        }
    }
}
