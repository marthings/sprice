//
//  PriceChangeIndicator.swift
//  Spotprice
//

import SwiftUI

struct PriceChangeIndicator: View {
    let current: Double?
    let next: Double?

    var body: some View {
        if let current, let next {
            let change = next - current
            let isIncrease = change > 0
            let icon = isIncrease ? "arrow.up" : change < 0 ? "arrow.down" : "minus"
            let color: Color = isIncrease ? .red : change < 0 ? .green : .secondary

            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
    }
}
