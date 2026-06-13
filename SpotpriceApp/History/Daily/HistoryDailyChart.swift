import SwiftUI
import Charts

struct HistoryDailyChart: View {
    let days: [HistoricalEnergySummaryValue]
    @Binding var selectedDay: HistoricalEnergySummaryValue?

    private var sortedDays: [HistoricalEnergySummaryValue] {
        days.sorted { $0.periodStart < $1.periodStart }
    }

    private var hasMultipleCoverageTypes: Bool {
        Set(sortedDays.map(\.dataCoverage)).count > 1
    }

    private struct PlottableDay: Identifiable {
        let day: HistoricalEnergySummaryValue
        let value: Double
        let label: String
        var id: HistoricalEnergySummaryValue.ID { day.id }
    }

    private var plottableDays: [PlottableDay] {
        sortedDays.compactMap { day in
            if let cost = day.totalCostSEK {
                return PlottableDay(day: day, value: cost, label: "Kostnad")
            }
            if let consumption = day.totalConsumptionKWh {
                return PlottableDay(day: day, value: consumption, label: "Förbrukning")
            }
            if let avgPrice = day.averageSpotPriceOrePerKWh {
                return PlottableDay(day: day, value: avgPrice / 100, label: "Snittpris")
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Chart {
                ForEach(plottableDays) { entry in
                    BarMark(
                        x: .value("Dag", entry.day.periodStart, unit: .day),
                        y: .value(entry.label, entry.value)
                    )
                    .foregroundStyle(coverageGradient(entry.day.dataCoverage))
                    .cornerRadius(4)
                    .opacity(selectedDay == nil || selectedDay?.id == entry.day.id ? 1.0 : 0.3)
                }

                if let selectedDay {
                    RuleMark(x: .value("Vald dag", selectedDay.periodStart))
                        .foregroundStyle(DS.Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                            HistoryDayCalloutView(day: selectedDay, showCoverageBadge: hasMultipleCoverageTypes)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: chartXAxisStride(for: sortedDays.count))) { value in
                    AxisGridLine()
                        .foregroundStyle(.tertiary)
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.day()))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.tertiary)
                    AxisTick()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .number.precision(.fractionLength(0)))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.secondary)
                        }
                    }
                }
            }
            .frame(height: 200)
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectedDay = findNearestDay(
                                        at: value.location,
                                        in: sortedDays,
                                        chartWidth: geometry.size.width
                                    )
                                }
                                .onEnded { value in
                                    if value.translation.width < 5 && value.translation.height < 5 {
                                        selectedDay = nil
                                    }
                                }
                        )
                }
            }

            HistoryCoverageLegend(days: sortedDays)
        }
    }

    private func coverageGradient(_ coverage: HistoricalEnergyDataCoverage) -> LinearGradient {
        let color = coverage.displayColor
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func chartXAxisStride(for dayCount: Int) -> Int {
        switch dayCount {
        case ...7: return 1
        case ...14: return 2
        case ...21: return 3
        default: return 5
        }
    }

    private func findNearestDay(
        at location: CGPoint,
        in days: [HistoricalEnergySummaryValue],
        chartWidth: CGFloat
    ) -> HistoricalEnergySummaryValue? {
        guard !days.isEmpty, chartWidth > 0 else { return nil }

        let dayIndex = Int((location.x / chartWidth) * Double(days.count))
        let clampedIndex = max(0, min(dayIndex, days.count - 1))
        return days[clampedIndex]
    }
}