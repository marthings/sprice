//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

struct ChartCalloutView: View {
    let bucket: PriceBucket
    let dayData: DayChartData
    var tariff: SimplifiedTariff? = nil

    private var priceCategory: PriceCategory {
        DS.Color.categoryForPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
    }

    private var priceColor: Color {
        DS.Color.forCategory(priceCategory)
    }
    
    private var totalCostPerKWh: Double? {
        guard let tariff = tariff else { return nil }
        let service = TotalCostService()
        return service.calculatePricePerKWh(spotPriceOre: bucket.orePerKWh, tariff: tariff)
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

            if let totalCost = totalCostPerKWh {
                // Show total cost as main value
                HStack(spacing: DS.Spacing.xs) {
                    Text(String(format: "%.2f", totalCost))
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("kr/kWh")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
                
                // Spot price in breakdown
                HStack(spacing: DS.Spacing.xs) {
                    Text("Spotpris:")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                    Text("\(Int(bucket.orePerKWh.rounded()))")
                        .font(DS.Font.medium(11).monospacedDigit())
                        .foregroundStyle(priceColor)
                    Text("öre/kWh")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fallback to spot price only
                HStack(spacing: DS.Spacing.xs) {
                    Text("\(Int(bucket.orePerKWh.rounded()))")
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(priceColor)
                    Text("öre/kWh")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
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
