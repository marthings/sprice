import SwiftUI
import Charts

struct HistoryMonthDaysChart: View {
    let days: [MonthDayCost]
    let isCurrentMonth: Bool
    let hasProvider: Bool
    var temperatures: [Date: Double] = [:]
    @Binding var openedDay: HistoryDayRoute?

    @State private var selectedDay: MonthDayCost?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Kostnad per dag",
                paragraphs: infoParagraphs,
                legend: temperaturePoints.isEmpty ? [] : [
                    SectionInfoLegendItem(color: DS.Color.accent, label: "Linjen visar temperaturen ute")
                ]
            )

            if days.allSatisfy({ $0.costKr == nil }) {
                Text(HistoryInsights.missingConsumptionMessage(hasProvider: hasProvider))
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var infoParagraphs: [String] {
        var parts: [String] = []
        if isCurrentMonth {
            parts.append("Varje stapel är vad en dag har kostat hittills den här månaden. Tryck på en dag för att se timmarna.")
        } else {
            parts.append("Varje stapel är vad en dag har kostat. Tryck på en dag för att se timmarna.")
        }
        if !temperaturePoints.isEmpty {
            parts.append("Linjen är temperaturen ute. Skalan till höger hör till linjen.")
            parts.append("Temperaturen kommer från Open-Meteo för den ort du valt under Inställningar.")
        }
        return parts
    }

    private var temperaturePoints: [(date: Date, temp: Double)] {
        let calendar = Calendar.energyHistory
        return days.compactMap { day in
            temperatures[calendar.startOfDay(for: day.date)].map { (day.date, $0) }
        }
    }

    private var temperatureDomain: ClosedRange<Double> {
        let values = temperaturePoints.map(\.temp)
        let lo = (values.min() ?? 0) - 2
        let hi = (values.max() ?? 1) + 2
        return min(lo, hi - 1)...max(hi, lo + 1)
    }

    private var chartAccessibility: String {
        if let lo = temperaturePoints.map(\.temp).min(), let hi = temperaturePoints.map(\.temp).max() {
            return "Stapeldiagram över kostnad per dag, med dygnstemperatur från \(TemperatureAdjustment.degrees(lo)) till \(TemperatureAdjustment.degrees(hi))"
        }
        return "Stapeldiagram över kostnad per dag den här månaden"
    }

    @ViewBuilder
    private var chartContent:
 some View {
        let expensive = mostExpensiveDay
        if let expensive, let cost = expensive.costKr {
            Text("Dyrast var \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "Dyraste dagen är \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kronor"
                )
        }
        if !temperaturePoints.isEmpty {
            ChartCaption("Staplarna är kronor, linjen är temperaturen ute.")
        }

        ZStack {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Dag", day.date, unit: .day),
                    y: .value("kr", day.costKr ?? 0)
                )
                .foregroundStyle(barColor(for: day, expensiveID: expensive?.id))
                .cornerRadius(3)
                .opacity(barOpacity(for: day))
            }

            if let selectedDay {
                RuleMark(x: .value("Vald dag", selectedDay.date, unit: .day))
                    .foregroundStyle(DS.Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                        ChartValueCallout(
                            title: AppFormatters.shortDayAndMonth(selectedDay.date),
                            value: selectedDay.costKr.map { "\(AppFormatters.wholeNumber($0)) kr" } ?? "–"
                        )
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisTick()
                    .foregroundStyle(.tertiary)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        HistoryChartAxis.dayLabel(date)
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
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .historyChartPlotStyle()

        if !temperaturePoints.isEmpty {
            Chart {
                ForEach(temperaturePoints, id: \.date) { point in
                    LineMark(
                        x: .value("Dag", point.date, unit: .day),
                        y: .value("Temperatur", point.temp)
                    )
                    .foregroundStyle(DS.Color.accent.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                    PointMark(
                        x: .value("Dag", point.date, unit: .day),
                        y: .value("Temperatur", point.temp)
                    )
                    .foregroundStyle(DS.Color.accent)
                    .symbolSize(16)
                }
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: temperatureDomain)
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            Text("\(Int(temp.rounded()))°")
                                .font(DS.Font.footnote)
                                .foregroundStyle(DS.Color.accentText)
                        }
                    }
                }
            }
            .historyChartPlotStyle()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        }
        .frame(height: chartHeight)
        .spriceChartMotion(days.map(\.costKr), selectedDay?.id, temperaturePoints.map(\.temp))
        .zIndex(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibility)
        .overlay {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let day = nearestDay(at: value.location, chartWidth: geometry.size.width)
                                if selectedDay?.id != day?.id {
                                    selectedDay = day
                                }
                            }
                            .onEnded { value in
                                guard let day = nearestDay(at: value.location, chartWidth: geometry.size.width) else {
                                    return
                                }
                                if selectedDay?.id != day.id {
                                    selectedDay = day
                                }
                                if abs(value.translation.width) < 8 && abs(value.translation.height) < 8 {
                                    open(day)
                                }
                            }
                    )
            }
        }
        .accessibilityLabel("Stapeldiagram över kostnad per dag, i kronor")
        .accessibilityRepresentation {
            ForEach(days) { day in
                Button(accessibilityLabel(for: day)) {
                    open(day)
                }
            }
        }
    }

    private var mostExpensiveDay: MonthDayCost? {
        days
            .compactMap { day -> (MonthDayCost, Double)? in
                guard let cost = day.costKr, cost > 0 else { return nil }
                return (day, cost)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    private var xAxisStride: Int {
        HistoryChartAxis.monthDayStride(dayCount: days.count)
    }

    private func nearestDay(at location: CGPoint, chartWidth: CGFloat) -> MonthDayCost? {
        guard !days.isEmpty, chartWidth > 0 else { return nil }
        let dayIndex = Int((location.x / chartWidth) * Double(days.count))
        let clampedIndex = max(0, min(dayIndex, days.count - 1))
        return days[clampedIndex]
    }

    private func barColor(for day: MonthDayCost, expensiveID: Date?) -> Color {
        if day.id == expensiveID {
            return DS.Color.danger
        }
        return DS.Color.info
    }

    private func barOpacity(for day: MonthDayCost) -> Double {
        if day.costKr == nil {
            return 0.18
        }
        if selectedDay == nil || selectedDay?.id == day.id {
            return 1
        }
        return 0.35
    }

    private func open(_ day: MonthDayCost) {
        openedDay = HistoryDayRoute(
            dayKey: EnergyHistoryKey.dayKey(for: day.date),
            date: day.date
        )
    }

    private func accessibilityLabel(for day: MonthDayCost) -> String {
        let heading = AppFormatters.weekdayDayMonth(day.date)
        if let cost = day.costKr {
            return "\(heading), \(AppFormatters.wholeNumber(cost)) kronor"
        }
        return "\(heading), ingen kostnad sparad"
    }
}
