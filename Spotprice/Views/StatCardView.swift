//
//  StatCardView.swift
//  Spotprice
//

import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(color)
                    Text(unit)
                        .font(DS.Font.medium(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.xs)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Radius.lg)
    }
}
