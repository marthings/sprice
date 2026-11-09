import SwiftUI
import Charts

struct ConsumptionInsightsScreen: View {
    let route: ConsumptionInsightsRoute
    let costProfile: CostProfile
    let dailySummaries: [HistoricalEnergySummaryValue]
    let historyQuery: (any EnergyHistoryQuerying)?
    var previewInsights: ConsumptionInsights? = nil

    @State private var insights: ConsumptionInsights?
    @State private var isLoading = true

    private var includeHypotheticalEffectTariff: Bool {
        ConsumptionSettings.shared.includeHypotheticalEffectTariff
    }

    var body: some View {
        ZStack {
            AppCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let insights {
                        ConsumptionInsightsContent(insights: insights)
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .accessibilityLabel("Räknar ut vad som drog i perioden")
                    } else {
                        AppStatusCard(
                            icon: "chart.bar",
                            title: "Ingen analys att visa",
                            message: "Förbrukning saknas för den här perioden.",
                            color: DS.Color.secondary
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl * 4)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, DS.Spacing.titleToContent, for: .scrollContent)
        }
        .navigationTitle("Vad drog?")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(route.id)-\(includeHypotheticalEffectTariff)") {
            await load()
        }
    }

    @MainActor
    private func load() async {
        if let previewInsights {
            insights = previewInsights
            isLoading = false
            return
        }
        isLoading = insights == nil
        insights = await ConsumptionInsightsService.insights(
            for: route,
            costProfile: costProfile,
            dailySummaries: dailySummaries,
            historyQuery: historyQuery
        )
        isLoading = false
    }
}

struct ConsumptionInsightsContent: View {
    let insights: ConsumptionInsights

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            summaryCard
            baseloadCard
            eventsCard
            diurnalCard
            peakCard
            resolutionFooter
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(periodTitle)
                .font(DS.Font.headline)
            ForEach(Array(insights.summarySentences.enumerated()), id: \.offset) { _, sentence in
                Text(sentence)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insights.summarySentences.joined(separator: " "))
    }

    private var periodTitle: String {
        if insights.periodKind == .day {
            return "Vad drog den här dagen?"
        }
        return "Vad drog i \(AppFormatters.monthName(insights.periodStart))?"
    }

    @ViewBuilder
    private var baseloadCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Grundlast")
                .font(DS.Font.headline)

            if let baseload = insights.baseload {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW))
                        .font(DS.Font.bold(28).monospacedDigit())
                    Text("alltid på")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Grundlast \(ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW))")

                Text("Det som alltid är på kostade ca \(AppFormatters.wholeNumber(baseload.costKr)) kr (\(AppFormatters.kWh(baseload.energyKWh))).")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let trend = baseloadTrend(baseload) {
                    Text(trend)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(
                    baseload.usedNightPercentile
                        ? "Beräknat som den låga nattnivån kl 00–05, tionde percentilen per dygn."
                        : "Bara dygnsvärden finns, så grundlasten är ett grovt golv från det lägsta dygnet."
                )
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Grundlasten kan inte räknas ut. Det saknas nattvärden med förbrukning.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func baseloadTrend(_ baseload: ConsumptionBaseloadInsight) -> String? {
        guard insights.periodKind == .month,
              let previous = baseload.previousPowerKW,
              previous > 0,
              let name = baseload.previousMonthName else {
            return nil
        }
        let percent = (baseload.powerKW - previous) / previous
        let than = name.contains("–") ? name : "i \(name)"
        if percent <= -0.05 {
            return "Lägre än \(than) (\(ConsumptionInsightsBuilder.powerPhrase(previous)))."
        }
        if percent >= 0.05 {
            return "Högre än \(than) (\(ConsumptionInsightsBuilder.powerPhrase(previous)))."
        }
        return "Ungefär som \(than)."
    }

    @ViewBuilder
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Toppar")
                .font(DS.Font.headline)

            Text("Vid varje topp står en gissning utifrån när den kom och hur den såg ut. Det är inte fakta.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if insights.events.isEmpty {
                Text(insights.eventsUnavailableReason ?? "Inga tydliga toppar över grundlasten.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(insights.events.enumerated()), id: \.element.id) { index, event in
                    eventRow(event, rank: index + 1)
                    if index < insights.events.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func eventRow(_ event: ConsumptionLoadEvent, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("\(rank). \(eventTimeSpan(event))")
                .font(DS.Font.semibold(14))
            Text("\(AppFormatters.wholeNumber(event.costKr)) kr · \(AppFormatters.kWh(event.energyKWh)) · topp \(ConsumptionInsightsBuilder.powerPhrase(event.peakKW))")
                .font(DS.Font.callout.monospacedDigit())
                .foregroundStyle(.primary)
            Text("\(event.shape.shapeLabel) — \(event.guess())")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Topp \(rank), \(eventTimeSpan(event)), \(AppFormatters.wholeNumber(event.costKr)) kronor, \(AppFormatters.kWh(event.energyKWh)), topp \(ConsumptionInsightsBuilder.powerPhrase(event.peakKW)). \(event.shape.shapeLabel), kanske \(event.guess())"
        )
    }

    private func eventTimeSpan(_ event: ConsumptionLoadEvent) -> String {
        let day = AppFormatters.shortDayAndMonth(event.start)
        let start = event.start.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale)
        )
        let end = event.end.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale)
        )
        return "\(day) \(start)–\(end)"
    }

    @ViewBuilder
    private var diurnalCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Tid på dygnet")
                .font(DS.Font.headline)

            if let diurnal = insights.diurnal {
                ConsumptionInsightsHourChart(diurnal: diurnal)

                Text("Mest pengar gick på \(diurnal.dominantBand.swedishName)en (\(AppFormatters.wholeNumber(dominantCost(diurnal))) kr).")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(diurnal.bands) { band in
                    HStack {
                        Text("\(band.band.swedishNameCapitalized) \(band.band.hourRangeLabel)")
                            .font(DS.Font.callout)
                        Spacer(minLength: DS.Spacing.sm)
                        Text("\(AppFormatters.wholeNumber(band.costKr)) kr")
                            .font(DS.Font.semibold(14).monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(band.band.swedishNameCapitalized) \(band.band.hourRangeLabel), \(AppFormatters.wholeNumber(band.costKr)) kronor")
                }

                Text("\(AppFormatters.wholeNumber(diurnal.expensiveShareKWh * 100)) % av kilowattimmarna köptes när priset var som högst.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let tip = diurnal.shiftTip {
                    Text("Flytta \(AppFormatters.kWh(tip.shiftKWh)) från \(tip.fromBand.swedishName) till \(tip.toBand.swedishName) hade sparat ca \(AppFormatters.wholeNumber(tip.savedKr)) kr.")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(insights.diurnalUnavailableReason ?? "Dygnsprofilen saknas.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func dominantCost(_ diurnal: ConsumptionDiurnalInsight) -> Double {
        diurnal.bands.first { $0.band == diurnal.dominantBand }?.costKr ?? 0
    }

    @ViewBuilder
    private var peakCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Effekttopp")
                .font(DS.Font.headline)

            if let peak = insights.powerPeak {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(ConsumptionInsightsBuilder.powerPhrase(peak.powerKW))
                        .font(DS.Font.bold(28).monospacedDigit())
                    Text(AppFormatters.powerPeakHourLabel(peak.hourStart))
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Högsta timmen \(ConsumptionInsightsBuilder.powerPhrase(peak.powerKW)), \(AppFormatters.powerPeakHourLabel(peak.hourStart))"
                )

                if peak.includeHypotheticalCost, let cost = peak.effectTariffCostKr {
                    Text("\(EffectTariffCopy.lineTitle): ca \(AppFormatters.wholeNumber(cost)) kr.")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    if peak.usesAveragePeaks {
                        Text("Din tariff räknar på medel av flera toppar. Här visas den högsta timmen, och avgiften på det medel som tariffen använder.")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if peak.includeHypotheticalCost {
                    Text(EffectTariffCopy.missingRate)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(insights.powerPeakUnavailableReason ?? "Ingen timtopp att visa.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var resolutionFooter: some View {
        Text(insights.resolution.swedishLabel)
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.Spacing.xxs)
            .accessibilityLabel(insights.resolution.swedishLabel)
    }
}

private struct ConsumptionInsightsHourChart: View {
    let diurnal: ConsumptionDiurnalInsight
    @State private var selectedHour: Double?

    var body: some View {
        Chart {
            ForEach(diurnal.hourBars) { bar in
                BarMark(
                    x: .value("Timme", Double(bar.hour)),
                    y: .value("kWh", bar.averageKWh)
                )
                .foregroundStyle(barColor(for: bar))
                .cornerRadius(2)
                .opacity(barOpacity(for: bar))
            }

            if let selected = selectedBar {
                RuleMark(x: .value("Vald timme", Double(selected.hour)))
                    .foregroundStyle(DS.Color.secondary.opacity(0.4))
                    .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                        ChartValueCallout(
                            title: "\(selected.hour)–\(selected.hour + 1)",
                            value: AppFormatters.kWh(selected.averageKWh)
                        )
                    }
            }
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 23.0]) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                if let hour = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(hour.rounded()))")
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
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.precision(.fractionLength(0...1)))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedHour)
        .chartPlotStyle { plot in
            plot.padding(.top, DS.Spacing.sm)
        }
        .frame(height: 160)
        .zIndex(1)
        .accessibilityLabel("Stapeldiagram över medelförbrukning per klockslag, i kilowattimmar")
        .accessibilityValue(chartAccessibilityValue)
    }

    private var selectedBar: ConsumptionHourProfileBar? {
        guard let selectedHour else { return nil }
        let hour = Int(selectedHour.rounded())
        return diurnal.hourBars.first { $0.hour == hour }
    }

    private func barColor(for bar: ConsumptionHourProfileBar) -> Color {
        let band = ConsumptionHourBand.band(forHour: bar.hour)
        if band == diurnal.dominantBand {
            return DS.Color.warning
        }
        return DS.Color.info
    }

    private func barOpacity(for bar: ConsumptionHourProfileBar) -> Double {
        guard let selectedHour else { return 1 }
        return bar.hour == Int(selectedHour.rounded()) ? 1 : 0.35
    }

    private var chartAccessibilityValue: String {
        let top = diurnal.hourBars.max { $0.averageKWh < $1.averageKWh }
        guard let top, top.averageKWh > 0 else {
            return "Ingen förbrukning per klockslag"
        }
        return "Högst i snitt kl \(top.hour), \(AppFormatters.kWh(top.averageKWh))"
    }
}
