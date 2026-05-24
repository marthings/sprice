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
            let isDecrease = change < 0

            // Use semantic icons and colors for accessibility
            let icon = isIncrease ? "arrow.up.right" : isDecrease ? "arrow.down.right" : "arrow.right"
            let color: Color = isIncrease ? DS.Color.danger : isDecrease ? DS.Color.success : DS.Color.secondary

            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .accessibilityLabel(isIncrease ? "Ökar" : isDecrease ? "Minskar" : "Stabilt")
        }
    }
}
