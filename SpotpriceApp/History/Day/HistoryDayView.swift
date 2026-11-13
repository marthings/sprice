import SwiftUI
import Charts

struct HistoryDayView: View {
    let date: Date
    let dayKey: String
    let dailySummary: HistoricalEnergySummaryValue?
    let costProfile: CostProfile
    let priceArea: String

    private let historyQuery: any EnergyHistoryQuerying
    private let previewSnapshot: HistoryDaySnapshot?

    @State private var snapshot: HistoryDaySnapshot?
    @State private var insights: ConsumptionInsights?
    @State private var openedInsights: HistoryDayInsightsRoute?
    @State private var loadFailed = false
    @State private var isPreliminary = false

    init(
        date: Date,
        dayKey: String,
        dailySummary: HistoricalEnergySummaryValue?,
        costProfile: CostProfile,
        priceArea: String,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        previewSnapshot: HistoryDaySnapshot? = nil
    ) {
        self.date = date
        self.dayKey = dayKey
        self.dailySummary = dailySummary
        self.costProfile = costProfile
        self.priceArea = priceArea
        self.historyQuery = historyQuery ?? EnergyHistoryQueryService()
        self.previewSnapshot = previewSnapshot
        _snapshot = State(initialValue: previewSnapshot)
    }

    @State private var debugScroll = ScrollPosition(edge: .top)

    var body: some View {
        ZStack {
            AppCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let snapshot {
                        HistoryDayTotals(snapshot: snapshot, isPreliminary: isPreliminary)
                        if snapshot.hasMeasuredUse || insights != nil {
                            ConsumptionInsightsDayTeaser(
                                insights: insights,
                                onOpen: openInsights
                            )
                        }
                        HistoryDayHourChart(snapshot: snapshot, evCharging: insights?.evCharging)
                        if snapshot.hasMeasuredUse {
                            HistoryDayExpensiveHours(hours: snapshot.expensiveHoursUsed)
                        }
                        if let split = snapshot.split, split.hasValues {
                            HistoryDayCostSplitView(split: split)
                        }
                    } else if loadFailed {
                        AppStatusCard(
                            icon: "clock.badge",
                            title: "Ingen timhistorik att visa",
                            message: "Det finns inga sparade timmar för den här dagen. Historiken fylls på när appen har hämtat priser.",
                            color: DS.Color.secondary
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollPosition($debugScroll)
#if DEBUG
            .task {
                guard DebugLaunch.scrollY > 0 else { return }
                try? await Task.sleep(for: .seconds(2))
                debugScroll.scrollTo(y: DebugLaunch.scrollY)
            }
#endif
            .scrollContentBackground(.hidden)
            .spriceScrollContentMargins()
        }
        .navigationTitle(AppFormatters.weekdayDayMonth(date))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openedInsights) { route in
            ConsumptionInsightsScreen(
                route: route.insights,
                costProfile: costProfile,
                dailySummaries: dailySummary.map { [$0] } ?? [],
                historyQuery: historyQuery
            )
        }
        .task(id: "\(ConsumptionSettings.shared.includeHypotheticalEffectTariff)-\(ConsumptionInsightsService.includeElectricCarGuess)") {
            guard previewSnapshot == nil else { return }
            await loadDay()
        }
    }

    /// Today is still being measured; other days follow their saved rows. Read from the
    /// store, since the summary handed in can be missing (or older than a new fetch).
    private func loadIsPreliminary() -> Bool {
        if Calendar.energyHistory.isDateInToday(date) { return true }
        let stored = try? historyQuery.loadMonthHistory(
            priceArea: priceArea,
            selectedMonthKey: EnergyHistoryKey.monthKey(for: date)
        ).dailySummaries.first { $0.periodKey == dayKey }
        return (stored ?? dailySummary)?.isPreliminary == true
    }

    private func openInsights() {
        openedInsights = HistoryDayInsightsRoute(
            insights: ConsumptionInsightsRoute(
                period: .day(dayKey: dayKey, date: date),
                priceArea: priceArea
            )
        )
    }

    @MainActor
    private func loadDay() async {
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            let calendar = Calendar.energyHistory
            let intervals = ConsumptionInsightsSampleData.previewIntervals().filter {
                calendar.isDate($0.intervalStart, inSameDayAs: date)
            }
            snapshot = HistoryDayInsights.snapshot(
                date: date,
                dailySummary: dailySummary,
                intervals: intervals,
                costProfile: costProfile
            )
            insights = await dayInsights(intervals: intervals)
            loadFailed = false
            return
        }
#endif
        isPreliminary = loadIsPreliminary()
        do {
            let intervals = try historyQuery.loadDayIntervals(dayKey: dayKey, priceArea: priceArea)
            snapshot = HistoryDayInsights.snapshot(
                date: date,
                dailySummary: dailySummary,
                intervals: intervals,
                costProfile: costProfile
            )
            insights = await dayInsights(intervals: intervals)
            loadFailed = false
        } catch {
            if dailySummary != nil {
                snapshot = HistoryDayInsights.snapshot(
                    date: date,
                    dailySummary: dailySummary,
                    intervals: [],
                    costProfile: costProfile
                )
                insights = await dayInsights(intervals: [])
                loadFailed = false
            } else {
                snapshot = nil
                insights = nil
                loadFailed = true
            }
        }
    }

    private func dayInsights(intervals: [HistoricalEnergyIntervalValue]) async -> ConsumptionInsights {
        let calendar = Calendar.energyHistory
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return await ConsumptionInsightsService.insights(
            intervals: intervals,
            dailySummaries: dailySummary.map { [$0] } ?? [],
            costProfile: costProfile,
            periodStart: start,
            periodEnd: end,
            periodKind: .day
        )
    }
}

private struct HistoryDayInsightsRoute: Hashable, Identifiable {
    let insights: ConsumptionInsightsRoute

    var id: String { insights.id }
}

private struct HistoryDayTotals: View {
    let snapshot: HistoryDaySnapshot
    var isPreliminary = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Dagens siffror",
                paragraphs: [
                    "Vad dagen kostade och hur mycket el som gick åt.",
                    "Är dagen inte slut visas det som hänt hittills."
                ] + (isPreliminary ? [HistoryPreliminaryCopy.day] : []),
                badge: isPreliminary ? "Preliminärt" : nil,
                badgeAccessibilityLabel: "Preliminärt, siffrorna kan ändras"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    dayMetrics
                }
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    dayMetrics
                }
            }

            if snapshot.costKr == nil && snapshot.kWh == nil {
                Text("Ingen förbrukning är sparad för dagen, så kurvan visar bara spotpriset.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if snapshot.isIncomplete {
                Text("Dagen är inte komplett.")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    @ViewBuilder
    private var dayMetrics: some View {
        if let cost = snapshot.costKr {
            dayMetric(value: AppFormatters.wholeNumber(cost), unit: "kr", label: "Kostnad", amount: cost)
        }
        if let kWh = snapshot.kWh {
            dayMetric(value: AppFormatters.kWhValue(kWh), unit: "kWh", label: "Förbrukning", amount: kWh)
        }
        if let paid = snapshot.paidKrPerKWh {
            dayMetric(
                value: paid.formatted(.number.precision(.fractionLength(2))),
                unit: "kr/kWh",
                label: "Betalt pris",
                amount: paid
            )
        }
    }

    /// The number is never wrapped or squeezed. If the unit does not fit beside it,
    /// the unit goes on the next line.
    private func dayMetric(value: String, unit: String, label: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    dayMetricNumber(value, amount: amount)
                    dayMetricUnit(unit)
                }
                VStack(alignment: .leading, spacing: 0) {
                    dayMetricNumber(value, amount: amount)
                    dayMetricUnit(unit)
                }
            }
            Text(label)
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }

    private func dayMetricNumber(_ value: String, amount: Double) -> some View {
        Text(value)
            .font(DS.Font.bold(28))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .spriceNumericText(amount)
    }

    private func dayMetricUnit(_ unit: String) -> some View {
        Text(unit)
            .font(DS.Font.unitLarge)
            .foregroundStyle(DS.Color.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct HistoryDayHourChart: View {
    let snapshot: HistoryDaySnapshot
    var evCharging: ConsumptionEVChargingInsight? = nil
    @State private var selectedCostHour: Date?
    @State private var selectedSpotHour: Date?
    @ScaledMetric(relativeTo: .body) private var costChartHeight: CGFloat = 160
    @ScaledMetric(relativeTo: .body) private var spotChartHeight: CGFloat = 96
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var hasCost: Bool {
        !snapshot.costHours.isEmpty
    }

    private var hasSpot: Bool {
        !snapshot.spotHours.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "När pengarna gick",
                paragraphs: [
                    "Varje stapel är vad en timme kostade.",
                    "Linjen under är elbörsens pris samma dag, utan påslag, elnät, skatt och moms.",
                    evCharging == nil
                        ? nil
                        : "De markerade timmarna ser ut som elbilsladdning. Det är en gissning, inte ett faktum."
                ].compactMap { $0 }
            )

            if let evLine = evCharging?.shortSummary {
                Text(evLine)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(evLine + ". Det är en gissning, inte ett faktum.")
            }

            if hasCost {
                Chart {
                    ForEach(snapshot.costHours) { hour in
                        BarMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("kr", hour.costKr ?? 0)
                        )
                        .foregroundStyle(costBarStyle(for: hour))
                        .cornerRadius(2)
                    }

                    if let selected = selectedCostHour.flatMap({ nearestHour(to: $0, in: snapshot.costHours) }),
                       let cost = selected.costKr {
                        RuleMark(x: .value("Vald timme", selected.start, unit: .hour))
                            .foregroundStyle(DS.Color.secondary.opacity(0.4))
                            .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                                ChartValueCallout(
                                    title: selected.hourRangeLabel,
                                    value: "\(AppFormatters.wholeNumber(cost)) kr"
                                )
                            }
                    }
                }
                .chartXScale(domain: hourDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: HistoryChartAxis.hourStrideHours)) { value in
                        AxisGridLine()
                            .foregroundStyle(.tertiary)
                        AxisTick()
                            .foregroundStyle(.tertiary)
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                HistoryChartAxis.hourLabel(date)
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
                .chartXSelection(value: $selectedCostHour)
                .historyChartPlotStyle()
                .spriceChartMotion(snapshot.costHours.map(\.costKr), selectedCostHour)
                .frame(height: costChartHeight)
                .zIndex(1)
                .accessibilityLabel("Stapeldiagram över kostnad per timme, i kronor")

                if let legend = costLegend {
                    Text(legend)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Förbrukning saknas, så det finns inga kronor per timme att visa.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasSpot {
                ChartCaption("Spotpris, kr/kWh")

                Chart {
                    ForEach(snapshot.spotHours) { hour in
                        LineMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("kr/kWh", (hour.spotOrePerKWh ?? 0) / 100)
                        )
                        .foregroundStyle(DS.Color.warning)
                        .interpolationMethod(.stepStart)
                        AreaMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("kr/kWh", (hour.spotOrePerKWh ?? 0) / 100)
                        )
                        .foregroundStyle(DS.Color.warning.opacity(0.12))
                        .interpolationMethod(.stepStart)
                    }

                    if let selected = selectedSpotHour.flatMap({ nearestHour(to: $0, in: snapshot.spotHours) }),
                       let spot = selected.spotOrePerKWh {
                        RuleMark(x: .value("Vald timme", selected.start, unit: .hour))
                            .foregroundStyle(DS.Color.secondary.opacity(0.4))
                            .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                                ChartValueCallout(
                                    title: selected.hourRangeLabel,
                                    value: AppFormatters.krPerKWh(spot / 100)
                                )
                            }
                    }
                }
                .chartXScale(domain: hourDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: HistoryChartAxis.hourStrideHours)) { value in
                        AxisGridLine()
                            .foregroundStyle(.tertiary)
                        AxisTick()
                            .foregroundStyle(.tertiary)
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                HistoryChartAxis.hourLabel(date)
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
                                Text(amount, format: .number.precision(.fractionLength(0...1)))
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...spotYMax)
                .chartXSelection(value: $selectedSpotHour)
                .historyChartPlotStyle()
                .spriceChartMotion(snapshot.spotHours.map(\.spotOrePerKWh), selectedSpotHour)
                .frame(height: spotChartHeight)
                .zIndex(1)
                .accessibilityLabel("Linjediagram över spotpris per timme, i kronor per kilowattimme")
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var hourDomain: ClosedRange<Date> {
        let start = snapshot.hours.first?.start ?? snapshot.date
        let last = snapshot.hours.last?.start ?? start
        return start...last.addingTimeInterval(3600)
    }

    private var spotYMax: Double {
        max((snapshot.spotHours.compactMap(\.spotOrePerKWh).max() ?? 100) / 100, 0.1) * 1.1
    }

    private func isCharging(_ hour: HistoryHourCost) -> Bool {
        evCharging?.containsHour(startingAt: hour.start) == true
    }

    private func costBarStyle(for hour: HistoryHourCost) -> AnyShapeStyle {
        if isCharging(hour) {
            // Striped when color alone must not carry the meaning.
            return differentiateWithoutColor ? AnyShapeStyle(ChargingHatch.paint) : AnyShapeStyle(DS.Color.warning)
        }
        if snapshot.expensiveHoursUsed.contains(where: { $0.id == hour.id }) {
            return AnyShapeStyle(DS.Color.danger)
        }
        return AnyShapeStyle(DS.Color.info)
    }

    /// Says in words what the colors mean, so the chart works without seeing them.
    private var costLegend: String? {
        var parts: [String] = []
        if evCharging != nil {
            parts.append("orange är troligen elbilsladdning")
        }
        if !snapshot.expensiveHoursUsed.isEmpty {
            parts.append("rött är dyra timmar du använde")
        }
        guard !parts.isEmpty else { return nil }
        parts.append("blått är resten")
        let sentence = parts.dropLast().joined(separator: ", ") + " och " + (parts.last ?? "")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    private func nearestHour(to date: Date, in hours: [HistoryHourCost]) -> HistoryHourCost? {
        hours.min { lhs, rhs in
            abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
        }
    }
}

private struct HistoryDayExpensiveHours: View {
    let hours: [HistoryHourCost]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Du drog el när det var dyrt",
                paragraphs: [
                    "Inte elbörsens dyraste timmar, utan de timmar du faktiskt använde el när det kostade mest."
                ]
            )

            if hours.isEmpty {
                Text("Det finns ingen mätt förbrukning att peka ut timmar från.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(hours) { hour in
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(hour.hourRangeLabel)
                                .font(DS.Font.callout)
                                .lineLimit(1)
                            Spacer(minLength: DS.Spacing.sm)
                            expensiveHourValues(hour)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(hour.hourRangeLabel)
                                .font(DS.Font.callout)
                            HStack(spacing: DS.Spacing.sm) {
                                expensiveHourValues(hour)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: hour))
                }
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    @ViewBuilder
    private func expensiveHourValues(_ hour: HistoryHourCost) -> some View {
        if let cost = hour.costKr {
            Text("\(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(16))
                .lineLimit(1)
        }
        if let kWh = hour.kWh {
            Text(AppFormatters.kWh(kWh, fractionLength: 0...1))
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)
        }
    }

    private func accessibilityLabel(for hour: HistoryHourCost) -> String {
        var parts = ["Klockan \(hour.hourRangeLabel)"]
        if let cost = hour.costKr {
            parts.append("\(AppFormatters.wholeNumber(cost)) kronor")
        }
        if let kWh = hour.kWh {
            parts.append(AppFormatters.kWh(kWh, fractionLength: 0...1))
        }
        return parts.joined(separator: ", ")
    }
}

private struct HistoryDayCostSplitRow: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let color: Color
}

private struct HistoryDayCostSplitView: View {
    let split: HistoryDayCostSplit

    private var splitInfoParagraphs: [String] {
        var parts = [
            "Färgfältet visar hur dagens kostnad fördelas mellan elhandel, elnät, skatt och moms. Beloppen finns under Visa beloppen.",
            "Beloppen är utan moms, som har en egen rad."
        ]
        if split.usedCurrentTariffs {
            parts.append("Äldre dagar saknade uppdelning, så den är räknad med dina priser och avgifter i dag.")
        }
        return parts
    }

    private var rows: [HistoryDayCostSplitRow] {
        [
            HistoryDayCostSplitRow(id: "energy", title: "Elhandel", amount: split.energyKr, color: DS.Color.info),
            HistoryDayCostSplitRow(id: "grid", title: "Elnät", amount: split.gridKr, color: DS.Color.warning),
            HistoryDayCostSplitRow(id: "tax", title: "Skatt på el", amount: split.taxKr, color: DS.Color.success),
            HistoryDayCostSplitRow(id: "vat", title: "Moms", amount: split.vatKr, color: Color.gray)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Så fördelades kostnaden",
                paragraphs: splitInfoParagraphs
            )

            GeometryReader { geometry in
                let total = max(split.totalKr, 0.0001)
                HStack(spacing: 0) {
                    ForEach(rows) { row in
                        Rectangle()
                            .fill(row.color)
                            .frame(width: geometry.size.width * CGFloat(max(row.amount, 0) / total))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            SpriceDisclosure(
                title: "Visa beloppen",
                openTitle: "Dölj beloppen",
                accessibilityName: "Belopp per del"
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
                    ForEach(rows) { row in
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DS.Spacing.sm) {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 8, height: 8)
                                Text(row.title)
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(DS.Color.secondary)
                                Spacer(minLength: DS.Spacing.sm)
                                Text(AppFormatters.kr(row.amount, fractionLength: 2))
                                    .font(DS.Font.footnote)
                                    .foregroundStyle(.primary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(row.title)
                                        .font(DS.Font.footnote)
                                        .foregroundStyle(DS.Color.secondary)
                                    Text(AppFormatters.kr(row.amount, fractionLength: 2))
                                        .font(DS.Font.footnote)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.title) \(AppFormatters.kr(row.amount, fractionLength: 2))")
                    }
                }
            }

        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }
}
