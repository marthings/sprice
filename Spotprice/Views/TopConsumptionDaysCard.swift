//
//  TopConsumptionDaysCard.swift
//  Spotprice
//

import SwiftUI
import Charts

struct TopConsumptionDaysCard: View {
    let dailyValues: [DailyConsumption]

    private var topDays: [DailyConsumption] {
        Array(
            dailyValues
                .sorted { $0.kWh > $1.kWh }
                .prefix(3)
                .sorted { $0.date < $1.date }  // Sort by date for display
        )
    }

    private var maxKWh: Double {
        topDays.map(\.kWh).max() ?? 1
    }

    private var hasData: Bool {
        !topDays.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: DS.Size.iconSmall))
                    .foregroundStyle(.secondary)
                Text("Effekttoppar denna månad")
                    .font(DS.Font.micro)
                    .foregroundStyle(.primary)
            }

            if hasData {
                Chart(topDays) { day in
                    BarMark(
                        x: .value("Dag", day.date, unit: .day),
                        y: .value("kWh", day.kWh)
                    )
                    .foregroundStyle(barColor(for: day.kWh).gradient)
                    .cornerRadius(DS.Radius.sm)
                    .annotation(position: .top, spacing: DS.Spacing.xxs) {
                        Text("\(Int(day.kWh.rounded()))")
                            .font(DS.Font.bold(11).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(dayLabel(date))
                                    .font(DS.Font.micro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(maxKWh * 1.3))
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

    private func barColor(for kWh: Double) -> Color {
        let ratio = kWh / maxKWh
        if ratio > 0.9 { return DS.Color.danger }
        if ratio > 0.7 { return DS.Color.warning }
        return .blue
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
