//
//  MenuBarLabel.swift
//  Spotprice
//

import SwiftUI

struct MenuBarLabel: View {
    let state: SpotPriceViewModel.State

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(state.labelColor.gradient)
                .symbolEffect(.pulse.wholeSymbol, isActive: state == .loading)

            Text(state.currentPriceLabel)
                .font(.custom("Avenir", size: 13).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(state.labelColor)

            if case .loaded = state {
                Text("öre")
                    .font(.custom("Avenir", size: 11).weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
