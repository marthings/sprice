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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(priceColor)
                    .frame(width: 8, height: 8)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(DS.Font.bold(16).monospacedDigit())
                    .foregroundStyle(priceColor)
                Text("öre/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            Text(priceLabel)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(priceColor.opacity(0.15), in: Capsule())
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
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
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
    }
}
