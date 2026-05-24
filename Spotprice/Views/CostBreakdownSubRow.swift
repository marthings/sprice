//
//  CostBreakdownSubRow.swift
//  Spotprice
//

import SwiftUI

struct CostBreakdownSubRow: View {
    let label: String
    let amount: Double

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.regular(10))
                .foregroundStyle(DS.Color.secondary)
                .padding(.leading, 14)

            Spacer()

            Text("\(amount.formatted(.number.precision(.fractionLength(0)))) kr")
                .font(DS.Font.regular(10).monospacedDigit())
                .foregroundStyle(DS.Color.secondary)
        }
    }
}
