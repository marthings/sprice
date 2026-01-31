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
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.custom("Avenir", size: 16).weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.custom("Avenir", size: 11).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
