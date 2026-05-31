//
//  CostBreakdownSubRow.swift
//  Spotprice
//

import SwiftUI

struct CostBreakdownSubRow: View {
    let label: String
    let amount: Double

    var body: some View {
        SharedCostBreakdownSubRow(label: label, amount: amount)
    }
}
