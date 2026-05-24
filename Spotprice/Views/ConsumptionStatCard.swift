//
//  ConsumptionStatCard.swift
//  Spotprice
//

import SwiftUI

struct ConsumptionStatCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String?
    let color: Color
    
    init(title: String, value: String, unit: String, subtitle: String? = nil, color: Color) {
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.color = color
    }

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
                        .foregroundStyle(DS.Color.secondary)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DS.Font.micro)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
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
