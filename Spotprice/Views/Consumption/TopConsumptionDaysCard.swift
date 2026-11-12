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
                        .font(DS.Font.footnote)
                        .foregroundStyle(.primary)
                    if let avg = averageKW {
                        Text("Snitt: \(avg.formatted(.number.precision(.fractionLength(1)))) kW")
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }

            if hasData {
                Chart(topPeaks) { peak in
                    BarMark(
                        x: .value("Tid", peakLabel(peak.date)),
                        y: .value("kW", peak.kW)
                    )
                    .foregroundStyle(Color("InfoColor"))
                    .cornerRadius(DS.Radius.sm)
                    .annotation(position: .top, spacing: DS.Spacing.xxs, overflowResolution: ChartCalloutOverflow.resolution) {
                        Text(peak.kW, format: .number.precision(.fractionLength(1)))
                            .font(DS.Font.bold(11))
                            .foregroundStyle(.primary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel {
                                Text(label)
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(maxKW * 1.3))
                .spriceChartMotion(topPeaks.map(\.kW))
                .frame(height: 70)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: DS.Spacing.xs) {
                        Text("Väntar på data")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondary)
                    }
                    Spacer()
                }
                .frame(height: 70)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .spriceCard(tone: .cost)
    }

    private func peakLabel(_ date: Date) -> String {
        AppFormatters.powerPeakLabel(date)
    }
}
