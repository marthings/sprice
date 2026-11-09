//
//  MenuBarLabel.swift
//  Spotprice
//

import Observation
import SwiftUI

struct MenuBarLabel: View {
    @Bindable var viewModel: SpotPriceViewModel

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(viewModel.menuBarLabelColor.gradient)
                .symbolEffect(.pulse.wholeSymbol, isActive: isLoading)

            menuBarPriceLabel
        }
    }

    private var isLoading: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }

    @ViewBuilder
    private var menuBarPriceLabel: some View {
        if let price = viewModel.menuBarPricePerKWh {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(price, format: .number.precision(.fractionLength(2)))
                Text("kr/kWh")
            }
        } else {
            Text("--")
        }
    }
}
