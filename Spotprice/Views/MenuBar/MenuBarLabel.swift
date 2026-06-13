//
//  MenuBarLabel.swift
//  Spotprice
//

import SwiftUI

struct MenuBarLabel: View {
    let state: SpotPriceViewModel.State

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(state.labelColor.gradient)
                .symbolEffect(.pulse.wholeSymbol, isActive: state == .loading)

            menuBarPriceLabel
        }
    }

    @ViewBuilder
    private var menuBarPriceLabel: some View {
        if let price = state.menuBarPricePerKWh {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(price, format: .number.precision(.fractionLength(2)))
                Text("kr/kWh")
            }
        } else {
            Text("--")
        }
    }
}