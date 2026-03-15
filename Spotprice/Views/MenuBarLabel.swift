//
//  MenuBarLabel.swift
//  Spotprice
//

import SwiftUI

struct MenuBarLabel: View {
    let state: SpotPriceViewModel.State
    let tariff: SimplifiedTariff?

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(state.labelColor.gradient)
                .symbolEffect(.pulse.wholeSymbol, isActive: state == .loading)

            Text(state.totalPriceLabel(tariff: tariff))

        }
    }
}
