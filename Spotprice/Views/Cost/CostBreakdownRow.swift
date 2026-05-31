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
        SharedCostBreakdownRow(
            label: label,
            amount: amount,
            color: color,
            style: .compact
        )
    }
}
