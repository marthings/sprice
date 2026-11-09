import SwiftUI
import Charts

struct HistoryMonthDaysChart: View {
    let days: [MonthDayCost]
    let isCurrentMonth: Bool
    let hasProvider: Bool
    @Binding var openedDay: HistoryDayRoute?

    @State private var selectedDay: MonthDayCost?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Kostnad per dag")
                    .font(DS.Font.headline)
                Text(introCopy)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if days.allSatisfy({ $0.costKr == nil }) {
                Text(HistoryInsights.missingConsumptionMessage(hasProvider: hasProvider))
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var introCopy: String {
        if isCurrentMonth {
            return "Så här har den pågående månaden kostat hittills. Tryck på en dag för att se timmarna."
        }
        return "Tryck på en dag för att se hur kostnaden fördelades över timmarna."
    }

    @ViewBuilder
    private var chartContent: some View {
        let expensive = mostExpensiveDay
        if let expensive, let cost = expensive.costKr {
            Text("Dyrast: \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "Dyraste dagen är \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kronor"
                )
        }

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
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.day())
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
        .chartPlotStyle { plot in
            plot.padding(.top, DS.Spacing.sm)
        }
        .frame(height: 180)
        .zIndex(1)
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

        if let selectedDay {
            Text(detailCopy(for: selectedDay))
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Öppna \(AppFormatters.weekdayDayMonth(selectedDay.date))") {
                open(selectedDay)
            }
            .font(DS.Font.callout)
        }

        Text("Tryck på en dag")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.secondary)
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
        switch days.count {
        case ...7: return 1
        case ...14: return 2
        case ...21: return 3
        default: return 5
        }
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

    private func detailCopy(for day: MonthDayCost) -> String {
        let heading = AppFormatters.weekdayDayMonth(day.date)
        if let cost = day.costKr {
            let kWhText: String
            if let kWh = day.kWh {
                kWhText = ", \(AppFormatters.kWh(kWh, fractionLength: 0...1))"
            } else {
                kWhText = ""
            }
            if day.isToday {
                return "Idag så långt: \(AppFormatters.wholeNumber(cost)) kr\(kWhText). Dagen är inte slut."
            }
            return "\(heading): \(AppFormatters.wholeNumber(cost)) kr\(kWhText)"
        }
        if day.isToday {
            return "Idag så långt finns ingen förbrukning sparad ännu."
        }
        return "\(heading): ingen förbrukning sparad för den här dagen."
    }
}
