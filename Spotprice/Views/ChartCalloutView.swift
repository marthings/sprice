//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

struct ChartCalloutView: View {
    let bucket: PriceBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(bucket.category.gradientColor)
                    .frame(width: 8, height: 8)
                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(.custom("Avenir", size: 11).weight(.semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                Text("\(Int(bucket.orePerKWh.rounded()))")
                    .font(.custom("Avenir", size: 16).weight(.bold).monospacedDigit())
                    .foregroundStyle(bucket.category.color)
                Text("öre/kWh")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(bucket.category.description)
                .font(.custom("Avenir", size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bucket.category.color.opacity(0.1), in: Capsule())
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("Surface"))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
    }
}
