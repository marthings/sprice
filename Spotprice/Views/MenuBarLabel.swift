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

            Text(state.currentPriceLabel)
                .font(DS.Font.medium(13).monospacedDigit())
                .foregroundStyle(state.labelColor)

            if case .loaded = state {
                Text("öre")
                    .font(DS.Font.medium(11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
