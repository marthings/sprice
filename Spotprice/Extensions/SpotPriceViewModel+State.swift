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
            let now = Date()
            if let currentBucket = payload.day.buckets.first(where: { $0.start <= now && $0.end > now }) {
                return currentBucket.category.color
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
