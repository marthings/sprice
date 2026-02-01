//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

struct ChartCalloutView: View {
    let bucket: PriceBucket
    let dayData: DayChartData

    private var priceCategory: PriceCategory {
        DS.Color.categoryForPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
    }

    private var priceColor: Color {
        DS.Color.forCategory(priceCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Time range with accessible category icon
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: priceCategory.accessibilityIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(priceColor)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(.primary)
            }

            // Price display
            HStack(spacing: DS.Spacing.xs) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(DS.Font.bold(16).monospacedDigit())
                    .foregroundStyle(priceColor)
                Text("öre/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            // Accessible badge with icon + text label
            PriceLevelBadge(category: priceCategory, style: .full)
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.15), radius: DS.Spacing.sm, x: 0, y: DS.Spacing.xs)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
