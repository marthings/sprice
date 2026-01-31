//
//  PriceCategory+UI.swift
//  Spotprice
//

import SwiftUI

extension PriceCategory {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var gradientColor: LinearGradient {
        switch self {
        case .low:
            return LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .top, endPoint: .bottom)
        case .medium:
            return LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .top, endPoint: .bottom)
        case .high:
            return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom)
        }
    }

    var description: String {
        switch self {
        case .low: return "Lågt pris"
        case .medium: return "Medelpris"
        case .high: return "Högt pris"
        }
    }
}

extension DayChartData {
    func upcomingBuckets(limit: Int) -> [PriceBucket] {
        let now = Date()
        let upcoming = buckets.filter { $0.start >= now }

        if upcoming.isEmpty {
            return Array(buckets.suffix(limit))
        }

        return Array(upcoming.prefix(limit))
    }
}
