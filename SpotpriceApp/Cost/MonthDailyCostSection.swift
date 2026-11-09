import SwiftUI
import Charts

struct MonthDailyCostSection: View {
    let priceArea: String
    let profile: CostProfile
    let hasProvider: Bool
    var forecastKr: Double? = nil
    var hypotheticalEffectTariffKr: Double? = nil

    @State private var days: [MonthDayCost] = []
    @State private var selectedDay: MonthDayCost?
    @State private var loadFailed = false
    @State private var didLoad = false

    private var calendar: Calendar { .energyHistory }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Kostnad per dag")
                    .font(DS.Font.headline)

                Text(introCopy)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let hypotheticalEffectTariffKr {
                    Text("\(EffectTariffCopy.lineTitle): ca \(AppFormatters.wholeNumber(hypotheticalEffectTariffKr)) kr för månaden. \(EffectTariffCopy.dailyBarsNote)")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            "\(EffectTariffCopy.lineTitle), \(AppFormatters.wholeNumber(hypotheticalEffectTariffKr)) kronor för månaden"
                        )
                }
            }

            if !didLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if loadFailed || days.allSatisfy({ $0.costKr == nil }) {
                emptyMessage(emptyStateCopy)
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .cost)
        .task(id: priceArea) {
            await loadDays()
        }
        .onChange(of: hasProvider) { _, _ in
            Task { await loadDays() }
        }
    }

    private var introCopy: String {
        if forecastKr != nil {
            return "Staplarna visar vad varje dag har kostat. Linjen är kostnaden hittills, den streckade delen är prognosen till månadens slut."
        }
        return "Så här har månaden kostat hittills. Tryck på en stapel för att se den dagen."
    }

    @ViewBuilder
    private var chartContent: some View {
        let expensive = mostExpensiveDay
        if let expensive, let cost = expensive.costKr {
            Text("Dyrast: \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Dyraste dagen är \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kronor")
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
        .chartXScale(domain: monthRange ?? defaultDomain)
        .chartYScale(domain: 0...(dailyYMax * 1.18))
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
        .frame(height: 196)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotFrame = proxy.plotFrame.map { geometry[$0] } ?? geometry.frame(in: .local)
                ZStack(alignment: .topLeading) {
                    MonthCumulativeProjectionShape(
                        proxy: proxy,
                        plotFrame: plotFrame,
                        points: cumulativePoints,
                        projection: projectionSegment,
                        yMax: lineYMax
                    )
                    .accessibilityHidden(true)

                    if let forecastKr, let endPoint = projectionEndPoint(proxy: proxy, plotFrame: plotFrame) {
                        ChartValueCallout(
                            title: nil,
                            value: "Prognos: \(AppFormatters.wholeNumber(forecastKr)) kr"
                        )
                        .position(endPoint)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }

                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let date: Date = proxy.value(atX: value.location.x) else { return }
                                    let day = days.first { calendar.isDate($0.date, inSameDayAs: date) }
                                    if let day, selectedDay?.id != day.id {
                                        selectedDay = day
                                    }
                                }
                        )
                }
            }
        }
        .zIndex(1)
        .accessibilityLabel(chartAccessibilityLabel)

        if let forecastKr {
            seriesLegend
            Text("Månaden ser ut att landa på cirka \(AppFormatters.wholeNumber(forecastKr)) kr")
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Månaden ser ut att landa på cirka \(AppFormatters.wholeNumber(forecastKr)) kronor")
        }

        if let selectedDay {
            Text(detailCopy(for: selectedDay))
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        }

        Text("Stapeln för idag visar bara det som har hänt hittills.")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var seriesLegend: some View {
        HStack(spacing: DS.Spacing.md) {
            legendSwatch(color: DS.Color.info, label: "Per dag")
            legendLine(style: StrokeStyle(lineWidth: 2), label: "Hittills")
            legendLine(style: StrokeStyle(lineWidth: 2, dash: [5, 4]), label: "Prognos")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Per dag som staplar, hittills som heldragen linje, prognos som streckad linje")
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 8)
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private func legendLine(style: StrokeStyle, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Capsule()
                .stroke(DS.Color.brand, style: style)
                .frame(width: 16, height: 2)
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var emptyStateCopy: String {
        if hasProvider {
            return "Förbrukningen för den här månaden har inte kommit in ännu. När den finns ser du vad varje dag har kostat."
        }
        return "Gå till Inställningar och lägg till förbrukning. Då kan du se vad varje dag har kostat den här månaden."
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.callout)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
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

    private var monthRange: ClosedRange<Date>? {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return nil }
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
            return interval.start...interval.start
        }
        return interval.start...calendar.startOfDay(for: lastDay)
    }

    private var defaultDomain: ClosedRange<Date> {
        let start = days.first?.date ?? Date()
        let end = days.last?.date ?? start
        return start...end
    }

    private var xAxisStride: Int {
        let count = monthDayCount
        switch count {
        case ...7: return 1
        case ...14: return 2
        case ...21: return 3
        default: return 5
        }
    }

    private var monthDayCount: Int {
        guard let monthRange else { return max(days.count, 1) }
        return (calendar.dateComponents([.day], from: monthRange.lowerBound, to: monthRange.upperBound).day ?? 0) + 1
    }

    private var dailyYMax: Double {
        max(days.compactMap(\.costKr).max() ?? 1, 1)
    }

    private var cumulativePoints: [MonthCumulativePoint] {
        var sum = 0.0
        var points: [MonthCumulativePoint] = []
        for day in days {
            if let cost = day.costKr {
                sum += cost
                points.append(MonthCumulativePoint(date: day.date, value: sum))
            }
        }
        return points
    }

    private var spentSoFarKr: Double {
        cumulativePoints.last?.value ?? 0
    }

    private var lineYMax: Double {
        max(forecastKr ?? 0, spentSoFarKr, 1) * 1.12
    }

    private var projectionSegment: MonthProjectionSegment? {
        guard let forecastKr, let last = cumulativePoints.last, let monthRange else { return nil }
        if calendar.isDate(last.date, inSameDayAs: monthRange.upperBound) {
            return nil
        }
        return MonthProjectionSegment(
            fromDate: last.date,
            fromValue: last.value,
            toDate: monthRange.upperBound,
            toValue: forecastKr
        )
    }

    private var chartAccessibilityLabel: String {
        if let forecastKr {
            return "Stapeldiagram över kostnad per dag den här månaden, med ackumulerad kostnad och prognos \(AppFormatters.wholeNumber(forecastKr)) kronor"
        }
        return "Stapeldiagram över kostnad per dag den här månaden"
    }

    private func projectionEndPoint(proxy: ChartProxy, plotFrame: CGRect) -> CGPoint? {
        guard let forecastKr, let monthRange, lineYMax > 0 else { return nil }
        guard let x = proxy.position(forX: monthRange.upperBound) else { return nil }
        let yRatio = CGFloat(forecastKr / lineYMax)
        let y = plotFrame.maxY - (plotFrame.height * min(max(yRatio, 0), 1))
        let labelOffsetX: CGFloat = 78
        let clampedX = min(max(x - 56, plotFrame.minX + labelOffsetX), plotFrame.maxX - 72)
        let clampedY = min(max(y - 16, plotFrame.minY + 18), plotFrame.maxY - 18)
        return CGPoint(x: clampedX, y: clampedY)
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

    private func detailCopy(for day: MonthDayCost) -> String {
        let heading = AppFormatters.weekdayDayMonth(day.date)
        if let cost = day.costKr {
            let kWhText: String
            if let kWh = day.kWh {
                kWhText = " · \(AppFormatters.kWh(kWh, fractionLength: 0...1))"
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

    @MainActor
    private func loadDays() async {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthKey = EnergyHistoryKey.monthKey(for: now, calendar: calendar)

        do {
            let history = try EnergyHistoryQueryService().loadMonthHistory(
                priceArea: priceArea,
                selectedMonthKey: monthKey
            )
            days = MonthDailyCostBuilder.bars(
                from: history.dailySummaries,
                profile: profile,
                now: now,
                calendar: calendar
            )
            loadFailed = false
        } catch {
            days = []
            loadFailed = true
        }
        didLoad = true
    }
}

private struct MonthCumulativePoint {
    let date: Date
    let value: Double
}

private struct MonthProjectionSegment {
    let fromDate: Date
    let fromValue: Double
    let toDate: Date
    let toValue: Double
}

private struct MonthCumulativeProjectionShape: View {
    let proxy: ChartProxy
    let plotFrame: CGRect
    let points: [MonthCumulativePoint]
    let projection: MonthProjectionSegment?
    let yMax: Double

    var body: some View {
        ZStack {
            Path { path in
                addLine(to: &path, points: points)
            }
            .stroke(DS.Color.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            if let projection {
                Path { path in
                    addLine(
                        to: &path,
                        points: [
                            MonthCumulativePoint(date: projection.fromDate, value: projection.fromValue),
                            MonthCumulativePoint(date: projection.toDate, value: projection.toValue)
                        ]
                    )
                }
                .stroke(
                    DS.Color.brand,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4])
                )

                if let end = position(for: projection.toDate, value: projection.toValue) {
                    Circle()
                        .fill(DS.Color.brand)
                        .frame(width: 7, height: 7)
                        .position(end)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func addLine(to path: inout Path, points: [MonthCumulativePoint]) {
        var started = false
        for point in points {
            guard let location = position(for: point.date, value: point.value) else { continue }
            if started {
                path.addLine(to: location)
            } else {
                path.move(to: location)
                started = true
            }
        }
    }

    private func position(for date: Date, value: Double) -> CGPoint? {
        guard yMax > 0, let x = proxy.position(forX: date) else { return nil }
        let yRatio = CGFloat(value / yMax)
        let y = plotFrame.maxY - (plotFrame.height * min(max(yRatio, 0), 1))
        return CGPoint(x: x, y: y)
    }
}

struct MonthDayCost: Identifiable, Equatable {
    let date: Date
    let costKr: Double?
    let kWh: Double?
    let isToday: Bool

    var id: Date { date }
}

enum MonthDailyCostBuilder {
    static func bars(
        from summaries: [HistoricalEnergySummaryValue],
        profile: CostProfile,
        now: Date,
        calendar: Calendar
    ) -> [MonthDayCost] {
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        return bars(
            from: summaries,
            profile: profile,
            monthStart: monthStart,
            lastDay: now,
            now: now,
            calendar: calendar
        )
    }

    static func bars(
        from summaries: [HistoricalEnergySummaryValue],
        profile: CostProfile,
        monthStart: Date,
        lastDay: Date,
        now: Date,
        calendar: Calendar
    ) -> [MonthDayCost] {
        let summariesByDay = Dictionary(
            summaries.map { (EnergyHistoryKey.dayKey(for: $0.periodStart, calendar: calendar), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let service = TotalCostService.shared
        var bars: [MonthDayCost] = []
        var dayStart = monthStart
        let lastDayStart = calendar.startOfDay(for: lastDay)

        while dayStart <= lastDayStart {
            let key = EnergyHistoryKey.dayKey(for: dayStart, calendar: calendar)
            let isToday = calendar.isDate(dayStart, inSameDayAs: now)
            let summary = summariesByDay[key]
            let hoursInPeriod = isToday
                ? max(now.timeIntervalSince(calendar.startOfDay(for: now)) / 3600, 1 / 60)
                : 24
            let kWh = summary?.totalConsumptionKWh
            let cost = dayCostKr(
                summary: summary,
                kWh: kWh,
                hoursInPeriod: hoursInPeriod,
                profile: profile,
                service: service
            )

            bars.append(MonthDayCost(date: dayStart, costKr: cost, kWh: kWh, isToday: isToday))
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = next
        }

        return bars
    }

    private static func dayCostKr(
        summary: HistoricalEnergySummaryValue?,
        kWh: Double?,
        hoursInPeriod: Double,
        profile: CostProfile,
        service: TotalCostService
    ) -> Double? {
        if let kWh, kWh > 0, let spot = summary?.averageSpotPriceOrePerKWh {
            return service.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spot,
                profile: profile,
                hoursInPeriod: hoursInPeriod
            ).totalKr
        }
        return summary?.totalCostSEK
    }
}
