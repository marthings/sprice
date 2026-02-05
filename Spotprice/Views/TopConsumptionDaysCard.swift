//
//  TopConsumptionDaysCard.swift
//  Spotprice
//

import SwiftUI
import Charts

struct TopConsumptionDaysCard: View {
    let peaks: [PowerPeak]

    private var topPeaks: [PowerPeak] {
        Array(peaks.prefix(3).sorted { $0.date < $1.date })
    }

    private var maxKW: Double {
        topPeaks.map(\.kW).max() ?? 1
    }

    private var averageKW: Double? {
        guard !topPeaks.isEmpty else { return nil }
        return topPeaks.map(\.kW).reduce(0, +) / Double(topPeaks.count)
    }

    private var hasData: Bool {
        !topPeaks.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Effekttoppar denna månad")
                        .font(DS.Font.micro)
                        .foregroundStyle(.primary)
                    if let avg = averageKW {
                        Text("Snitt: \(String(format: "%.1f", avg)) kW")
                            .font(DS.Font.micro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.md)

            if hasData {
                Chart(topPeaks) { peak in
                    BarMark(
                        x: .value("Tid", peakLabel(peak.date)),
                        y: .value("kW", peak.kW)
                    )
                    .foregroundStyle(Color("InfoColor"))
                    .cornerRadius(DS.Radius.sm)
                    .annotation(position: .top, spacing: DS.Spacing.xxs) {
                        Text(String(format: "%.1f", peak.kW))
                            .font(DS.Font.bold(11).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel {
                                Text(label)
                                    .font(DS.Font.micro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(maxKW * 1.3))
                .frame(height: 70)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: DS.Spacing.xs) {
                        Text("Väntar på data")
                            .font(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 70)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: DS.Radius.md)
    }

    private func peakLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }
}
