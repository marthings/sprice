//
//  ConsumptionStatCard.swift
//  Spotprice
//

import SwiftUI

struct ConsumptionStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(DS.Font.medium(11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: DS.Radius.md)
    }
}
