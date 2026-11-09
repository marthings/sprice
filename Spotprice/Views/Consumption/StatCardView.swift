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
        MetricCard(
            title: title,
            value: value,
            unit: unit,
            icon: icon,
            color: color,
            titleColor: .primary,
            valueFont: DS.Font.bold(16).monospacedDigit(),
            unitFont: DS.Font.medium(11),
            iconSize: 14,
            layout: .vertical
        )
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.xs)
        .spriceCard(tone: .cost)
    }
}
