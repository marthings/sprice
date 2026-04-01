//
//  CostBreakdownRow.swift
//  Spotprice
//

import SwiftUI

struct CostBreakdownRow: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(label)
                .font(DS.Font.medium(11))
                .foregroundStyle(.primary)

            Spacer()

            Text("\(amount.formatted(.number.precision(.fractionLength(0)))) kr")
                .font(DS.Font.medium(11).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}
