import SwiftUI
import Charts

struct HistoryWeekdayPattern: View {
    let averages: [HistoryWeekdayAverage]
    @State private var selectedLabel: String?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Snitt per veckodag",
                paragraphs: [
                    "Vad varje veckodag har kostat i snitt den här månaden.",
                    "Med få dagar att jämföra blir det mer osäkert."
                ]
            )

            if averages.allSatisfy({ $0.averageCostKr == nil }) {
                Text("Veckodagarna syns när det finns dagar med sparad kostnad.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {

                Chart {
                    ForEach(averages) { weekday in
                        BarMark(
                            x: .value("Veckodag", weekday.label),
                            y: .value("kr", weekday.averageCostKr ?? 0)
                        )
                        .foregroundStyle(barColor(for: weekday))
                        .cornerRadius(3)
                        .opacity(selectedLabel == nil || selectedLabel == weekday.label ? 1 : 0.4)
                    }

                    if let selected = averages.first(where: { $0.label == selectedLabel }),
                       let cost = selected.averageCostKr {
                        RuleMark(x: .value("Veckodag", selected.label))
                            .foregroundStyle(DS.Color.secondary.opacity(0.35))
                            .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                                ChartValueCallout(value: "\(AppFormatters.wholeNumber(cost)) kr")
                            }
                    }
                }
                .chartXSelection(value: $selectedLabel)
                .chartXAxis {
                    AxisMarks { value in
                        AxisTick()
                            .foregroundStyle(.tertiary)
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                HistoryChartAxis.label(label)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(.tertiary)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .number.precision(.fractionLength(0)))
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .historyChartPlotStyle()
                .spriceChartMotion(averages.map(\.averageCostKr), selectedLabel)
                .frame(height: chartHeight)
                .zIndex(1)
                .accessibilityLabel("Stapeldiagram över snittkostnad per veckodag, i kronor")
                .accessibilityRepresentation {
                    ForEach(averages) { weekday in
                        Text(accessibilityLabel(for: weekday))
                    }
                }

                if let peak = peakWeekday, let cost = peak.averageCostKr {
                    let kWhText = peak.averageKWh.map { ", \(AppFormatters.kWh($0, fractionLength: 0...1))" } ?? ""
                    Text("Dyrast i snitt: \(peak.label), \(AppFormatters.wholeNumber(cost)) kr\(kWhText)")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if HistoryInsights.weekdayPatternIsSparse(averages) {
                    Text("Få dagar att jämföra än, så ta det som en fingervisning.")
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var peakWeekday: HistoryWeekdayAverage? {
        averages
            .compactMap { weekday -> (HistoryWeekdayAverage, Double)? in
                guard let cost = weekday.averageCostKr else { return nil }
                return (weekday, cost)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    private func barColor(for weekday: HistoryWeekdayAverage) -> Color {
        if weekday.id == peakWeekday?.id {
            return DS.Color.danger
        }
        return DS.Color.info
    }

    private func accessibilityLabel(for weekday: HistoryWeekdayAverage) -> String {
        if let cost = weekday.averageCostKr {
            let kWhText = weekday.averageKWh.map { ", \(AppFormatters.kWh($0, fractionLength: 0...1))" } ?? ""
            return "\(weekday.label), snitt \(AppFormatters.wholeNumber(cost)) kronor\(kWhText)"
        }
        return "\(weekday.label), ingen kostnad"
    }
}
