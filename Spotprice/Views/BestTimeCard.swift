//
//  BestTimeCard.swift
//  Spotprice
//

import SwiftUI

struct BestTimeCard: View {
    let buckets: [PriceBucket]

    private struct Activity {
        let name: String
        let kWh: Double
        let hours: Double
        let icon: String
        let color: Color
    }

    private static let activities = [
        Activity(name: "Dusch (10 min)", kWh: 6.0, hours: 1, icon: "drop.fill", color: .blue),
        Activity(name: "Pizza i ugn", kWh: 1.1, hours: 1, icon: "flame.fill", color: DS.Color.warning),
        Activity(name: "Ladda bilen", kWh: 45.0, hours: 4, icon: "bolt.car.fill", color: DS.Color.success),
    ]

    private struct Recommendation {
        let activity: Activity
        let windowStart: Date
        let windowEnd: Date
        let avgPrice: Double
        let savings: Double
        let isNow: Bool
    }

    var body: some View {
        let recommendations = computeRecommendations()

        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Bästa tid idag")
                        .font(DS.Font.semibold(14))
                        .foregroundStyle(.primary)
                }

                VStack(spacing: DS.Spacing.xs) {
                    ForEach(recommendations, id: \.activity.name) { rec in
                        recommendationRow(rec)
                    }
                }

                Text("Jämfört med nuvarande pris")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }

    // MARK: - Row

    private func recommendationRow(_ rec: Recommendation) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: rec.activity.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(rec.activity.color)
                .frame(width: 16)

            Text(rec.activity.name)
                .font(DS.Font.medium(11))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if rec.isNow {
                Text("Nu är billigast")
                    .font(DS.Font.medium(11))
                    .foregroundStyle(DS.Color.success)
            } else {
                Text(timeLabel(rec))
                    .font(DS.Font.medium(11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("spara \(Int(rec.savings.rounded()))kr")
                .font(DS.Font.medium(11).monospacedDigit())
                .foregroundStyle(rec.savings > 0 ? DS.Color.success : .secondary)
                .frame(minWidth: 60, alignment: .trailing)
        }
    }

    // MARK: - Time Label

    private func timeLabel(_ rec: Recommendation) -> String {
        let cal = Calendar.current
        let startHour = cal.component(.hour, from: rec.windowStart)
        let endHour = cal.component(.hour, from: rec.windowEnd)

        if rec.activity.hours <= 1 {
            return String(format: "kl %02d", startHour)
        } else {
            return String(format: "kl %02d–%02d", startHour, endHour)
        }
    }

    // MARK: - Algorithm

    private func computeRecommendations() -> [Recommendation] {
        let now = Date()

        // Filter to remaining buckets (current + future)
        let remaining = buckets.filter { $0.end > now }
        guard !remaining.isEmpty else { return [] }

        // Current price
        let currentPrice = remaining.first { $0.start <= now && $0.end > now }?.orePerKWh
        guard let currentPrice else { return [] }

        // Bucket duration in hours
        guard let first = remaining.first else { return [] }
        let bucketDuration = first.end.timeIntervalSince(first.start) / 3600.0
        guard bucketDuration > 0 else { return [] }

        var results: [Recommendation] = []

        for activity in Self.activities {
            let bucketsNeeded = Int(ceil(activity.hours / bucketDuration))

            // Need enough remaining buckets
            guard remaining.count >= bucketsNeeded else { continue }

            // Find cheapest consecutive window
            var bestStart = 0
            var bestAvg = Double.infinity

            for i in 0...(remaining.count - bucketsNeeded) {
                let window = remaining[i..<(i + bucketsNeeded)]
                let avg = window.reduce(0.0) { $0 + $1.orePerKWh } / Double(bucketsNeeded)
                if avg < bestAvg {
                    bestAvg = avg
                    bestStart = i
                }
            }

            let windowStartBucket = remaining[bestStart]
            let windowEndBucket = remaining[bestStart + bucketsNeeded - 1]

            // Savings in kr: (currentPrice - windowAvg) / 100 * kWh
            let savings = (currentPrice - bestAvg) / 100.0 * activity.kWh

            // Is now the best time?
            let isNow = windowStartBucket.start <= now && now < windowStartBucket.end

            results.append(Recommendation(
                activity: activity,
                windowStart: windowStartBucket.start,
                windowEnd: windowEndBucket.end,
                avgPrice: bestAvg,
                savings: savings,
                isNow: isNow
            ))
        }

        return results
    }
}
