//
//  CostCardView.swift
//  Spotprice
//

import SwiftUI

struct CostCardView: View {
    let title: String
    let mainCost: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Avenir", size: 12).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(description)
                        .font(.custom("Avenir", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(mainCost)
                    .font(.custom("Avenir", size: 15).weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("kr")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Cost Calculation Helper

extension CostCardView {
    static func calculateCost(kWh: Double, priceInOre: Double) -> String {
        let costInKr = (priceInOre / 100.0) * kWh
        return String(format: "%.2f", costInKr)
    }
}
