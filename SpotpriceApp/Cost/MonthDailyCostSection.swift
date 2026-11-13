import SwiftUI
import os
import Charts

struct MonthDailyCostSection: View {
    let priceArea: String
    let profile: CostProfile
    let hasProvider: Bool
    var hidesEmptyExplanation: Bool = false
    var forecastKr: Double? = nil
    var measuredThrough: Date? = nil
    var hypotheticalEffectTariffKr: Double? = nil
    var baseload: ConsumptionBaseloadInsight? = nil
    var onOpenBaseload: (() -> Void)? = nil

    @State private var days: [MonthDayCost] = []
    @State private var selectedDay: MonthDayCost?
    @State private var selectedDayTiming: String?
    @State private var loadFailed = false
    @State private var didLoad = false
    /// Old minus today's price for days this month under an older agreement version.
    @State private var liveAdjustmentKr: Double = 0
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 196

    private var calendar: Calendar { .energyHistory }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Kostnad per dag",
                paragraphs: infoParagraphs,
                legend: infoLegend
            )

            if let hypotheticalEffectTariffKr {
                Text("\(EffectTariffCopy.lineTitle): ca \(AppFormatters.wholeNumber(hypotheticalEffectTariffKr)) kr för månaden.")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.warningText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "\(EffectTariffCopy.lineTitle), \(AppFormatters.wholeNumber(hypotheticalEffectTariffKr)) kronor för månaden"
                    )
            }

            if !didLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if loadFailed || days.allSatisfy({ $0.costKr == nil }) {
                if !hidesEmptyExplanation {
                    emptyMessage(emptyStateCopy)
                }
                if !hasProvider {
                    DemoModeButton()
                }
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .cost)
        .task(id: priceArea) {
            await loadDays()
        }
        .onChange(of: hasProvider) { _, _ in
            Task { await loadDays() }
        }
        .onChange(of: profile) { _, _ in
            Task { await loadDays() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .energyHistoryDidUpdate)) { _ in
            Task { await loadDays() }
        }
        .onChange(of: selectedDay) { _, day in
            Task { await loadTiming(for: day) }
        }
    }

    private var infoParagraphs: [String] {
        var parts = [
            "Varje stapel är vad en dag har kostat. Tryck på en stapel för att se dagen."
        ]
        if resolvedForecastKr != nil {
            parts.append("Den heldragna linjen är vad månaden har kostat hittills. Den streckade är en prognos till månadens slut, utifrån hur månaden har sett ut.")
        } else {
            parts.append("Så här har månaden kostat hittills.")
        }
        parts.append("Dagens stapel växer under dagen, och mätvärden kan komma in med lite fördröjning.")
        if days.contains(where: { $0.isPreliminary && $0.costKr != nil }) {
            parts.append(MonthDayCost.preliminaryExplanation)
        }
        if hypotheticalEffectTariffKr != nil {
            parts.append("Effektavgiften gäller hela månaden, så den syns inte i staplarna.")
        }
        if let baseload {
            parts.append(Self.baseloadTitle(baseload))
            parts.append("Det är sådant som står på dygnet runt, även när du inte gör något särskilt. Öppna Vad drog? för mer.")
        }
        return parts
    }

    private var infoLegend: [SectionInfoLegendItem] {
        guard resolvedForecastKr != nil else { return [] }
        return [
            SectionInfoLegendItem(color: DS.Color.info, label: "Staplarna är kostnaden per dag"),
            SectionInfoLegendItem(color: DS.Color.brand, label: "Heldragen linje är kostnaden hittills"),
            SectionInfoLegendItem(id: "prognos", color: DS.Color.brand, label: "Streckad linje är prognosen")
        ]
    }

    @ViewBuilder
    private var chartContent: some View {
        let expensive = mostExpensiveDay
        if let forecastStatusCopy {
            Text(forecastStatusCopy)
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .spriceNumericText(spentSoFarKr + (resolvedForecastKr ?? 0))
                .accessibilityLabel(forecastStatusCopy)
        }
        if let expensive, let cost = expensive.costKr {
            Text("Dyrast var \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Dyraste dagen är \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kronor")
        }

        ZStack {
            dailyBarsChart(expensive: expensive)
            if resolvedForecastKr != nil || !cumulativePoints.isEmpty {
                cumulativeLineChart
            }
        }
        .frame(height: chartHeight)
        .spriceChartMotion(days.map(\.costKr), selectedDay?.id, resolvedForecastKr, cumulativePoints.map(\.value))
        .zIndex(1)
        .accessibilityLabel(chartAccessibilityLabel)

        if resolvedForecastKr != nil {
            seriesLegend
        }

        if let selectedDayTiming {
            Text(selectedDayTiming)
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(selectedDayTiming)
        }

        if let baseload {
            if let onOpenBaseload {
                Button(action: onOpenBaseload) {
                    InsightRow(
                        icon: "house",
                        title: Self.baseloadTitle(baseload),
                        detail: "Visa Vad drog?",
                        showsChevron: true
                    )
                }
                .buttonStyle(SpriceCardPressButtonStyle())
                .accessibilityHint("Öppnar Vad drog?")
            } else {
                InsightRow(icon: "house", title: Self.baseloadTitle(baseload))
            }
        }
    }

    static func baseloadTitle(_ baseload: ConsumptionBaseloadInsight) -> String {
        let power = ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW)
        let kronor = AppFormatters.wholeNumber(baseload.costKr)
        return "Det du alltid drar är runt \(power), ungefär \(kronor) kr den här månaden."
    }

    private var seriesLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.md) {
                seriesLegendItems
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                seriesLegendItems
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Per dag som staplar, hittills som heldragen linje, prognos som streckad linje")
    }

    @ViewBuilder
    private var seriesLegendItems: some View {
        legendSwatch(color: DS.Color.info, label: "Per dag")
        legendLine(style: StrokeStyle(lineWidth: 2), label: "Hittills")
        legendLine(style: StrokeStyle(lineWidth: 2, dash: [5, 4]), label: "Prognos")
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 8)
            Text(label)
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private func legendLine(style: StrokeStyle, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Capsule()
                .stroke(DS.Color.brand, style: style)
                .frame(width: 16, height: 2)
            Text(label)
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private func dailyBarsChart(expensive: MonthDayCost?) -> some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Dag", day.date, unit: .day),
                    y: .value("Kronor per dag", day.costKr ?? 0)
                )
                .foregroundStyle(barColor(for: day, expensiveID: expensive?.id))
                .cornerRadius(3)
                .opacity(barOpacity(for: day))
                .accessibilityLabel(AppFormatters.weekdayDayMonth(day.date))
                .accessibilityValue(day.accessibilityValue)
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
                    axisAmountLabel(value.as(Double.self), visible: true, trailing: false)
                }
            }
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    axisAmountLabel(value.as(Double.self), visible: false, trailing: true)
                }
            }
        }
        .historyChartPlotStyle()
        .chartOverlay { proxy in
            GeometryReader { _ in
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

    private var cumulativeLineChart: some View {
        Chart {
            ForEach(cumulativePoints) { point in
                LineMark(
                    x: .value("Dag", point.date, unit: .day),
                    y: .value("Kronor totalt", point.value),
                    series: .value("Serie", "Hittills")
                )
                .foregroundStyle(DS.Color.brand)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let projection = projectionSegment {
                ForEach([
                    MonthCumulativePoint(date: projection.fromDate, value: projection.fromValue),
                    MonthCumulativePoint(date: projection.toDate, value: projection.toValue)
                ]) { point in
                    LineMark(
                        x: .value("Dag", point.date, unit: .day),
                        y: .value("Kronor totalt", point.value),
                        series: .value("Serie", "Prognos")
                    )
                    .foregroundStyle(DS.Color.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                }

                PointMark(
                    x: .value("Dag", projection.toDate, unit: .day),
                    y: .value("Kronor totalt", projection.toValue)
                )
                .foregroundStyle(DS.Color.brand)
                .symbolSize(40)
                .annotation(position: .top, alignment: .leading, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.fitToPlot) {
                    if let resolvedForecastKr {
                        ChartValueCallout(
                            value: "Prognos: \(AppFormatters.wholeNumber(resolvedForecastKr)) kr"
                        )
                    }
                }
            }
        }
        .chartXScale(domain: monthRange ?? defaultDomain)
        .chartYScale(domain: 0...lineYMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisGridLine()
                    .foregroundStyle(.clear)
                AxisTick()
                    .foregroundStyle(.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        HistoryChartAxis.dayLabel(date)
                            .opacity(0)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.clear)
                AxisTick()
                    .foregroundStyle(.clear)
                AxisValueLabel {
                    axisAmountLabel(value.as(Double.self), visible: false, trailing: false)
                }
            }
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisTick()
                AxisValueLabel {
                    axisAmountLabel(value.as(Double.self), visible: true, trailing: true)
                }
            }
        }
        .historyChartPlotStyle()
        .chartLegend(.hidden)
        .chartBackground { (_: ChartProxy) in
            Color.clear
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func axisAmountLabel(_ amount: Double?, visible: Bool, trailing: Bool) -> some View {
        if let amount {
            Text(amount, format: .number.precision(.fractionLength(0)))
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
                .frame(minWidth: 36, alignment: trailing ? .leading : .trailing)
                .opacity(visible ? 1 : 0)
                .accessibilityHidden(!visible)
                .accessibilityLabel(
                    trailing
                        ? "\(AppFormatters.wholeNumber(amount)) kronor totalt"
                        : "\(AppFormatters.wholeNumber(amount)) kronor per dag"
                )
        }
    }

    private var emptyStateCopy: String {
        if hasProvider {
            return "Månadens förbrukning har inte kommit in än. Så fort den finns ser du vad varje dag kostat."
        }
        return "Lägg till förbrukning i Inställningar, så ser du vad varje dag kostar."
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
        HistoryChartAxis.monthDayStride(dayCount: monthDayCount)
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

    private var effectiveMeasuredThrough: Date? {
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            return ConsumptionInsightsSampleData.previewMeasuredThrough()
        }
#endif
        return measuredThrough
    }

    private var forecastStatusCopy: String? {
        guard spentSoFarKr > 0, let forecast = resolvedForecastKr else { return nil }
        let month = AppFormatters.monthName(Date()).lowercased()
        let through = effectiveMeasuredThrough
            ?? days.last(where: { $0.costKr != nil })?.date
        let until = through.map { AppFormatters.relativeStamp($0) } ?? ""
        var text = "\(AppFormatters.wholeNumber(spentSoFarKr)) kr hittills, runt \(AppFormatters.wholeNumber(forecast)) kr för hela \(month)."
        if !until.isEmpty {
            text += " Mätt till \(until)."
        }
        return text
    }

    private var resolvedForecastKr: Double? {
        if let fromBars = forecastFromSpentBars {
            return fromBars + (hypotheticalEffectTariffKr ?? 0)
        }
        return forecastKr
    }

    private var forecastFromSpentBars: Double? {
        guard spentSoFarKr > 0 else { return nil }
        let through: Date?
        if let effectiveMeasuredThrough {
            through = effectiveMeasuredThrough
        } else if let lastDay = days.last(where: { $0.costKr != nil })?.date {
            through = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay))
                ?? lastDay
        } else {
            through = nil
        }
        return MonthDailyCostBuilder.forecast(
            spentKr: spentSoFarKr,
            liveAdjustmentKr: liveAdjustmentKr,
            profile: profile,
            measuredThrough: through
        )
    }

    private var lineYMax: Double {
        max(resolvedForecastKr ?? 0, spentSoFarKr, 1) * 1.28
    }

    private var projectionSegment: MonthProjectionSegment? {
        guard let forecastKr = resolvedForecastKr, let last = cumulativePoints.last, let monthRange else { return nil }
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
        if let resolvedForecastKr {
            return "Stapeldiagram över kostnad per dag den här månaden, med ackumulerad kostnad och prognos \(AppFormatters.wholeNumber(resolvedForecastKr)) kronor"
        }
        return "Stapeldiagram över kostnad per dag den här månaden"
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
        let opacity = selectedDay == nil || selectedDay?.id == day.id ? 1 : 0.35
        return opacity * day.preliminaryOpacity
    }

    @MainActor
    private func loadTiming(for day: MonthDayCost?) async {
        guard let day else {
            selectedDayTiming = nil
            return
        }
        let dayKey = EnergyHistoryKey.dayKey(for: day.date, calendar: calendar)
        let intervals: [HistoricalEnergyIntervalValue]
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            intervals = ConsumptionInsightsSampleData.previewIntervals().filter {
                calendar.isDate($0.intervalStart, inSameDayAs: day.date)
            }
        } else {
            intervals = (try? EnergyHistoryQueryService().loadDayIntervals(dayKey: dayKey, priceArea: priceArea)) ?? []
        }
#else
        intervals = (try? EnergyHistoryQueryService().loadDayIntervals(dayKey: dayKey, priceArea: priceArea)) ?? []
#endif
        selectedDayTiming = CostUsageInsights.timing(intervals: intervals, profile: profile)?.title
    }

    @MainActor
    private func loadDays() async {
        if DemoMode.isActive { await DemoHistorySeeder.ensureSeeded() }
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthKey = EnergyHistoryKey.monthKey(for: now, calendar: calendar)

#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            days = MonthDailyCostBuilder.bars(
                from: ConsumptionInsightsSampleData.previewIntervals(now: now, calendar: calendar),
                profile: profile,
                now: now,
                calendar: calendar
            )
            loadFailed = false
            didLoad = true
            return
        }
#endif

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-historyAudit") {
            MonthDailyCostBuilder.auditLog(priceArea: priceArea, profile: profile, now: now, calendar: calendar)
        }
#endif
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
            liveAdjustmentKr = LiveMonthPricing.adjustment(priceArea: priceArea, current: profile, now: now, calendar: calendar)?.totalKr ?? 0
            loadFailed = false
        } catch {
            days = []
            loadFailed = true
        }
        didLoad = true
    }
}

private struct MonthCumulativePoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

private struct MonthProjectionSegment {
    let fromDate: Date
    let fromValue: Double
    let toDate: Date
    let toValue: Double
}

struct MonthDayCost: Identifiable, Equatable {
    let date: Date
    let costKr: Double?
    let kWh: Double?
    let isToday: Bool
    /// Some value or cost of the day may still change. Drawn a little lighter.
    var isPreliminary: Bool = false

    var id: Date { date }

    /// How much lighter a preliminary bar is drawn.
    var preliminaryOpacity: Double { isPreliminary ? 0.5 : 1 }

    var accessibilityValue: String {
        guard let costKr else { return "ingen kostnad sparad" }
        let amount = "\(AppFormatters.wholeNumber(costKr)) kronor"
        return isPreliminary ? "\(amount), preliminärt" : amount
    }

    static let preliminaryExplanation = "Ljusare staplar är preliminära. Mätvärden kan ändras de första två dygnen, och ett pris som inte är känt än kan också ändras."
}

enum MonthDailyCostBuilder {
    /// Month forecast from what is spent so far. Days under an older agreement version are
    /// done and keep their price; only today's version is extrapolated over the month.
    static func forecast(
        spentKr: Double,
        liveAdjustmentKr: Double,
        profile: CostProfile,
        measuredThrough: Date?,
        now: Date = Date()
    ) -> Double? {
        MonthlyCostEstimator().forecastMonth(
            spentKr: spentKr - liveAdjustmentKr,
            consumptionKWh: 0,
            spotPriceOre: 0,
            profile: profile,
            measuredThrough: measuredThrough,
            now: now
        ).map { $0.forecastKr + liveAdjustmentKr }
    }

    static func bars(
        from intervals: [HistoricalEnergyIntervalValue],
        profile: CostProfile,
        now: Date,
        calendar: Calendar
    ) -> [MonthDayCost] {
        let service = TotalCostService.shared
        let versions = HistoryPricing.savedVersions()
        var costByDay: [Date: (cost: Double, kWh: Double)] = [:]
        var profileByDay: [Date: CostProfile] = [:]
        for interval in intervals {
            let kWh = interval.consumptionKWh ?? 0
            guard kWh > 0 else { continue }
            let dayStart = calendar.startOfDay(for: interval.intervalStart)
            let hours = max(interval.intervalEnd.timeIntervalSince(interval.intervalStart) / 3600, 0)
            // Each day with the agreement version in force that day.
            let dayProfile = profileByDay[dayStart]
                ?? HistoryPricing.liveProfile(at: dayStart, current: profile, versions: versions)
            profileByDay[dayStart] = dayProfile
            let cost = service.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: interval.spotPriceOrePerKWh,
                profile: dayProfile,
                hoursInPeriod: hours
            ).totalKr
            let current = costByDay[dayStart] ?? (0, 0)
            costByDay[dayStart] = (current.cost + cost, current.kWh + kWh)
        }
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        var bars: [MonthDayCost] = []
        var dayStart = monthStart
        let lastDayStart = calendar.startOfDay(for: now)
        while dayStart <= lastDayStart {
            let values = costByDay[dayStart]
            bars.append(
                MonthDayCost(
                    date: dayStart,
                    costKr: values?.cost,
                    kWh: values?.kWh,
                    isToday: calendar.isDate(dayStart, inSameDayAs: now)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = next
        }
        return bars
    }

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
        let versions = HistoryPricing.savedVersions()
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
                isToday: isToday,
                hoursInPeriod: hoursInPeriod,
                profile: HistoryPricing.liveProfile(at: dayStart, current: profile, versions: versions),
                service: service
            )

            // Today is still being measured; other days follow their saved rows.
            bars.append(MonthDayCost(
                date: dayStart,
                costKr: cost,
                kWh: kWh,
                isToday: isToday,
                isPreliminary: isToday || summary?.isPreliminary == true
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = next
        }

        return bars
    }

    private static func dayCostKr(
        summary: HistoricalEnergySummaryValue?,
        kWh: Double?,
        isToday: Bool,
        hoursInPeriod: Double,
        profile: CostProfile,
        service: TotalCostService
    ) -> Double? {
        // Finished days use the saved cost: priced per interval with the version and fees
        // of that day, so the bars add up to the month total. Today is still running.
        if !isToday, let kWh, kWh > 0, let stored = summary?.totalCostSEK {
            return stored
        }
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

#if DEBUG
extension MonthDailyCostBuilder {
    /// `-historyAudit`: logs per month the month total, the day bars (now and with the old
    /// rule: today's profile on kWh times the day's average spot price) and the widget
    /// summary, and for the running month the live version adjustment and forecast.
    static func auditLog(priceArea: String, profile: CostProfile, now: Date, calendar: Calendar) {
        let query = EnergyHistoryQueryService()
        guard let history = try? query.loadMonthHistory(priceArea: priceArea, selectedMonthKey: nil) else { return }
        let service = TotalCostService.shared
        for month in history.months.sorted(by: { $0.periodStart < $1.periodStart }) {
            guard let days = try? query.loadMonthHistory(priceArea: priceArea, selectedMonthKey: month.periodKey).dailySummaries,
                  let interval = calendar.dateInterval(of: .month, for: month.periodStart) else { continue }
            let isCurrent = calendar.isDate(month.periodStart, equalTo: now, toGranularity: .month)
            let lastDay = isCurrent ? now : interval.end.addingTimeInterval(-1)
            let bars = Self.bars(from: days, profile: profile, monthStart: interval.start, lastDay: lastDay, now: now, calendar: calendar)
            let oldBars = days.reduce(0.0) { total, day in
                guard let kWh = day.totalConsumptionKWh, kWh > 0, let spot = day.averageSpotPriceOrePerKWh else {
                    return total + (day.totalCostSEK ?? 0)
                }
                return total + service.calculateTotalCost(kWh: kWh, spotPriceOre: spot, profile: profile, hoursInPeriod: 24).totalKr
            }
            let barSum = bars.compactMap(\.costKr).reduce(0, +)
            let widget = WidgetHistorySummaryCache.summary(monthKey: month.periodKey, priceArea: priceArea)?.totalCostSEK
            var line = "HistoryAudit \(month.periodKey) month=\(String(format: "%.4f", month.totalCostSEK ?? -1)) bars=\(String(format: "%.4f", barSum)) oldBars=\(String(format: "%.4f", oldBars)) widget=\(String(format: "%.4f", widget ?? -1))"
            if isCurrent {
                let adjustment = LiveMonthPricing.adjustment(priceArea: priceArea, current: profile, now: now, calendar: calendar)?.totalKr ?? 0
                let forecast = Self.forecast(spentKr: barSum, liveAdjustmentKr: adjustment, profile: profile, measuredThrough: now, now: now) ?? -1
                line += " liveAdjustment=\(String(format: "%.4f", adjustment)) forecastFromBars=\(String(format: "%.4f", forecast))"
            }
            let preliminaryDays = days.filter(\.isPreliminary).map(\.periodKey).sorted()
            let widgetPreliminary = WidgetHistorySummaryCache.summary(monthKey: month.periodKey, priceArea: priceArea)?.isPreliminary
            line += " preliminary=\(month.isPreliminary) widgetPreliminary=\(widgetPreliminary.map(String.init(describing:)) ?? "nil") preliminaryDays=\(preliminaryDays.joined(separator: ","))"
            AppLog.history.info("\(line, privacy: .public)")
        }
    }
}
#endif
