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
        MetricCard(
            title: title,
            value: value,
            unit: unit,
            color: color,
            titleColor: .primary,
            valueFont: DS.Font.bold(16).monospacedDigit(),
            unitFont: DS.Font.medium(11),
            subtitle: subtitle
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .spriceCard(tone: .cost)
    }
}
