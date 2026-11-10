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

    var body: some View {
        ZStack {
            AppCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let snapshot {
                        HistoryDayTotals(snapshot: snapshot)
                        if snapshot.hasMeasuredUse || insights != nil {
                            ConsumptionInsightsDayTeaser(
                                insights: insights,
                                onOpen: openInsights
                            )
                        }
                        HistoryDayHourChart(snapshot: snapshot)
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
                            message: "Det finns inga sparade intervall för den här dagen. Historik fylls på när appen har hämtat priser.",
                            color: DS.Color.secondary
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
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
        .task(id: ConsumptionSettings.shared.includeHypotheticalEffectTariff) {
            guard previewSnapshot == nil else { return }
            await loadDay()
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Dagens siffror",
                paragraphs: [
                    "Här ser du vad dagen kostade och hur mycket el som gick åt.",
                    "Om dagen inte är slut visas bara det som har hänt hittills."
                ]
            )

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                if let cost = snapshot.costKr {
                    dayMetric(value: AppFormatters.wholeNumber(cost), unit: "kr", label: "Kostnad")
                }
                if let kWh = snapshot.kWh {
                    dayMetric(value: AppFormatters.kWhValue(kWh), unit: "kWh", label: "Förbrukning")
                }
                if let paid = snapshot.paidKrPerKWh {
                    dayMetric(
                        value: paid.formatted(.number.precision(.fractionLength(2))),
                        unit: "kr/kWh",
                        label: "Betalt pris"
                    )
                }
            }

            if snapshot.costKr == nil && snapshot.kWh == nil {
                Text("Ingen förbrukning sparad för den här dagen. Kurvan visar bara spotpriset när det finns.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if snapshot.isIncomplete {
                Text("Dagen är inte komplett.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func dayMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(DS.Font.bold(28).monospacedDigit())
                Text(unit)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }
}

private struct HistoryDayHourChart: View {
    let snapshot: HistoryDaySnapshot
    @State private var selectedCostHour: Date?
    @State private var selectedSpotHour: Date?

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
                    "Staplarna visar vad varje timme kostade.",
                    "Linjen under är börsens elpris samma dag, utan påslag, nät, skatt och moms."
                ]
            )

            if hasCost {
                Chart {
                    ForEach(snapshot.costHours) { hour in
                        BarMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("kr", hour.costKr ?? 0)
                        )
                        .foregroundStyle(costBarColor(for: hour))
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
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedCostHour)
                .historyChartPlotStyle()
                .frame(height: 160)
                .zIndex(1)
                .accessibilityLabel("Stapeldiagram över kostnad per timme, i kronor")
            } else {
                Text("Ingen kostnad per timme att visa. Förbrukning saknas, så inga kronor räknas fram.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasSpot {
                Text("Spotpris, öre/kWh")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)

                Chart {
                    ForEach(snapshot.spotHours) { hour in
                        LineMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("öre/kWh", hour.spotOrePerKWh ?? 0)
                        )
                        .foregroundStyle(DS.Color.warning)
                        .interpolationMethod(.stepStart)
                        AreaMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("öre/kWh", hour.spotOrePerKWh ?? 0)
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
                                    value: "\(AppFormatters.oreValue(spot)) öre"
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
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedSpotHour)
                .historyChartPlotStyle()
                .frame(height: 96)
                .zIndex(1)
                .accessibilityLabel("Linjediagram över spotpris per timme, i öre per kilowattimme")
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

    private func costBarColor(for hour: HistoryHourCost) -> Color {
        if snapshot.expensiveHoursUsed.contains(where: { $0.id == hour.id }) {
            return DS.Color.danger
        }
        return DS.Color.info
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
                    "Listan visar inte börsens dyraste timme, utan de timmar du faktiskt använde när det kostade mest."
                ]
            )

            if hours.isEmpty {
                Text("Det finns ingen mätt förbrukning att peka ut timmar från.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(hours) { hour in
                    HStack {
                        Text(hour.hourRangeLabel)
                            .font(DS.Font.callout)
                            .frame(width: 56, alignment: .leading)
                        Spacer(minLength: DS.Spacing.sm)
                        if let cost = hour.costKr {
                            Text("\(AppFormatters.wholeNumber(cost)) kr")
                                .font(DS.Font.semibold(16).monospacedDigit())
                        }
                        if let kWh = hour.kWh {
                            Text(AppFormatters.kWh(kWh, fractionLength: 0...1))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.secondary)
                                .frame(width: 72, alignment: .trailing)
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
            "Färgfältet och listan visar hur dagens kostnad fördelas mellan elhandel, nät, skatt och moms.",
            "Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar."
        ]
        if split.usedCurrentTariffs {
            parts.append("Äldre rader saknade uppdelning. Det här är räknat med de priser och avgifter du har i dag.")
        }
        return parts
    }

    private var rows: [HistoryDayCostSplitRow] {
        [
            HistoryDayCostSplitRow(id: "energy", title: "Elhandel", amount: split.energyKr, color: DS.Color.info),
            HistoryDayCostSplitRow(id: "grid", title: "Nät", amount: split.gridKr, color: DS.Color.warning),
            HistoryDayCostSplitRow(id: "tax", title: "Skatt", amount: split.taxKr, color: DS.Color.success),
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

            ForEach(rows) { row in
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(row.color)
                        .frame(width: 8, height: 8)
                    Text(row.title)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(AppFormatters.kr(row.amount, fractionLength: 2))
                        .font(DS.Font.micro.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.title) \(AppFormatters.kr(row.amount, fractionLength: 2))")
            }

        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }
}
