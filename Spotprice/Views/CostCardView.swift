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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Font.semibold(12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(description)
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(mainCost)
                    .font(DS.Font.bold(15).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("kr")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Radius.lg)
    }
}

// MARK: - Cost Calculation Helper

extension CostCardView {
    static func calculateCost(kWh: Double, priceInOre: Double) -> String {
        let costInKr = (priceInOre / 100.0) * kWh
        return String(format: "%.2f", costInKr)
    }
}
