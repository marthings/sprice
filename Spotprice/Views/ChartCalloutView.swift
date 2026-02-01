//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

struct ChartCalloutView: View {
    let bucket: PriceBucket
    let dayData: DayChartData

    private var priceColor: Color {
        DS.Color.forPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(priceColor)
                    .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(DS.Font.bold(16).monospacedDigit())
                    .foregroundStyle(priceColor)
                Text("öre/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            Text(priceLabel)
                .font(DS.Font.regular(9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xxs)
                .background(priceColor.opacity(0.15), in: Capsule())
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

    private var priceLabel: String {
        let normalized = (bucket.orePerKWh - dayData.minOre) / max(dayData.maxOre - dayData.minOre, 1)
        if normalized <= 0.33 {
            return "Lågt pris"
        } else if normalized <= 0.66 {
            return "Medelpris"
        } else {
            return "Högt pris"
        }
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
