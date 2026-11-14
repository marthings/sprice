import SwiftUI
import Charts
import Accessibility
import UIKit

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

    private var includeElectricCarGuess: Bool {
        ConsumptionInsightsService.includeElectricCarGuess
    }

    @State private var debugScroll = ScrollPosition(edge: .top)

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
        .navigationTitle("Vad drog?")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(route.id)-\(includeHypotheticalEffectTariff)-\(includeElectricCarGuess)") {
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
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            summaryCard
            evChargingCard
            baseloadCard
            eventsCard
            diurnalCard
            peakCard
            resolutionFooter
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: periodTitle,
                paragraphs: [
                    "En kort sammanfattning av vad som drog, utifrån den förbrukning som finns sparad."
                ]
            )
            ForEach(Array(insights.summarySentences.enumerated()), id: \.offset) { _, sentence in
                Text(sentence)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
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
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Det du alltid drar",
                paragraphs: [
                    "Det du alltid drar är det som är igång hela tiden, även på natten. Det kallas grundlast.",
                    "Med timvärden räknas det från den låga nivån mellan midnatt och fem på morgonen. Finns bara dygnsvärden blir det ett grovt golv från det lägsta dygnet.",
                    "Watt (W) och kilowatt (kW) är hur mycket el som går åt just då. Går 1 kW i en timme blir det 1 kWh."
                ]
            )

            if let baseload = insights.baseload {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW))
                        .font(DS.Font.black(28))
                    Text("alltid på")
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Det du alltid drar, \(ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW))")

                Text("Det kostade ungefär \(AppFormatters.wholeNumber(baseload.costKr)) kr (\(AppFormatters.kWh(baseload.energyKWh))).")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let trend = baseloadTrend(baseload) {
                    Text(trend)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

            } else {
                Text("Det går inte att räkna ut än, för nattvärden med förbrukning saknas.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
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
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Toppar",
                paragraphs: [
                    "Vid varje topp står en gissning utifrån när den kom och hur den såg ut. Se det som en ledtråd, inte ett facit."
                ]
            )

            if insights.events.isEmpty {
                Text(insights.eventsUnavailableReason ?? "Inga tydliga toppar över det du alltid drar.")
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
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func eventRow(_ event: ConsumptionLoadEvent, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("\(rank). \(eventTimeSpan(event))")
                .font(DS.Font.semibold(14))
            Text("\(AppFormatters.wholeNumber(event.costKr)) kr, \(AppFormatters.kWh(event.energyKWh)), topp \(ConsumptionInsightsBuilder.powerPhrase(event.peakKW))")
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
            Text("\(event.shape.shapeLabel) — \(event.guess())")
                .font(DS.Font.footnote)
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
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Tid på dygnet",
                paragraphs: [
                    "Staplarna är medelförbrukningen per klockslag.",
                    "Under ser du hur kostnaden fördelas över morgon, dag, kväll och natt."
                ]
            )

            if let diurnal = insights.diurnal {
                ChartCaption("Snitt per klockslag, kWh")
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
                            .font(DS.Font.semibold(14))
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
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var peakInfoParagraphs: [String] {
        var parts = [
            "Timmen i perioden då mest el gick åt, i kilowatt (kW), alltså hur mycket el som gick åt just då.",
            EffectTariffCopy.explanation
        ]
        if insights.powerPeak?.usesAveragePeaks == true {
            parts.append("Elnätet räknar på ett medel av flera toppar. Här ser du den högsta timmen och avgiften på elnätets medel.")
        }
        return parts
    }

    private func dominantCost(_ diurnal: ConsumptionDiurnalInsight) -> Double {
        diurnal.bands.first { $0.band == diurnal.dominantBand }?.costKr ?? 0
    }

    @ViewBuilder
    private var peakCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Högsta timmen",
                paragraphs: peakInfoParagraphs
            )

            if let peak = insights.powerPeak {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(ConsumptionInsightsBuilder.powerPhrase(peak.powerKW))
                        .font(DS.Font.black(28))
                    Text(AppFormatters.powerPeakHourLabel(peak.hourStart))
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Högsta timmen \(ConsumptionInsightsBuilder.powerPhrase(peak.powerKW)), \(AppFormatters.powerPeakHourLabel(peak.hourStart))"
                )

                if peak.includeHypotheticalCost, let cost = peak.effectTariffCostKr {
                    Text("\(EffectTariffCopy.lineTitle): ca \(AppFormatters.wholeNumber(cost)) kr.")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.warningText)
                        .fixedSize(horizontal: false, vertical: true)
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
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    @ViewBuilder
    private var evChargingCard: some View {
        if let ev = insights.evCharging {
            VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
                SectionInfoHeader(
                    title: "Troligen elbilsladdning",
                    paragraphs: ElectricCarCopy.infoParagraphs
                )

                if ev.dayProfiles.isEmpty {
                    Text(ev.shortSummary)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(ev.shortSummary)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    ChartCaption("kWh per timme")
                    ForEach(ev.dayProfiles) { profile in
                        if ev.dayProfiles.count > 1 {
                            Text(AppFormatters.shortDayAndMonth(profile.day))
                                .font(DS.Font.footnote)
                                .foregroundStyle(DS.Color.secondary)
                        }
                        ConsumptionEVChargingHourChart(
                            profile: profile,
                            baseloadKW: ev.baseloadKW
                        )
                    }
                    evLegend(hasBaseload: (ev.baseloadKW ?? 0) > 0)
                }

                ForEach(Array(ev.sessions.enumerated()), id: \.element.id) { index, session in
                    evSessionRow(session, rank: ev.sessions.count == 1 ? nil : index + 1)
                    if index < ev.sessions.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(DS.Spacing.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spriceCard(tone: .history)
        }
    }

    /// Words for what the colors mean, so the chart reads the same without color.
    private func evLegend(hasBaseload: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                ChargingLegendSwatch(isCharging: true)
                Text(differentiateWithoutColor ? "Orange med streck: troligen laddning" : "Orange: troligen laddning")
            }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                ChargingLegendSwatch(isCharging: false)
                Text("Blå: övrig förbrukning")
            }
            if hasBaseload {
                Text("Streckad linje: det du alltid drar")
                    .padding(.leading, 18)
            }
        }
        .font(DS.Font.footnote)
        .foregroundStyle(DS.Color.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Orange staplar är timmar som troligen är laddning. Blå staplar är övrig förbrukning.")
    }

    private func evSessionRow(_ session: ConsumptionEVChargingSession, rank: Int?) -> some View {
        let title = rank.map { "\($0). \(evTimeSpan(session))" } ?? evTimeSpan(session)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.semibold(14))
            Text("\(AppFormatters.wholeNumber(session.costKr)) kr, \(AppFormatters.kWh(session.energyKWh)), \(evDuration(session))")
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evDuration(_ session: ConsumptionEVChargingSession) -> String {
        let hours = max(Int((session.end.timeIntervalSince(session.start) / 3600).rounded()), 1)
        return hours == 1 ? "1 timme" : "\(hours) timmar"
    }

    private func evTimeSpan(_ session: ConsumptionEVChargingSession) -> String {
        let day = AppFormatters.shortDayAndMonth(session.start)
        let start = session.start.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale)
        )
        let end = session.end.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(AppFormatters.swedishLocale)
        )
        return "\(day) \(start)–\(end)"
    }

    private func evAccessibilityLabel(_ ev: ConsumptionEVChargingInsight) -> String {
        var parts = [ev.shortSummary]
        for session in ev.sessions {
            parts.append(evTimeSpan(session))
        }
        parts.append("Det är en gissning, inte ett faktum.")
        return parts.joined(separator: ". ")
    }

    private var resolutionFooter: some View {
        Text(insights.resolution.swedishLabel)
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.Spacing.xxs)
            .accessibilityLabel(insights.resolution.swedishLabel)
    }
}

private struct ConsumptionEVChargingHourChart: View {
    let profile: ConsumptionEVDayProfile
    var baseloadKW: Double? = nil
    @State private var selectedHour: Double?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 112
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Chart {
            ForEach(profile.hours) { bar in
                BarMark(
                    x: .value("Timme", Double(bar.hour)),
                    y: .value("kWh", max(bar.kWh, 0))
                )
                .foregroundStyle(barStyle(for: bar))
                .cornerRadius(HistoryChartAxis.barRadius)
                .opacity(barOpacity(for: bar))
            }

            if let baseloadKW, baseloadKW > 0 {
                RuleMark(y: .value("Det du alltid drar", baseloadKW))
                    .foregroundStyle(DS.Color.secondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .accessibilityLabel("Det du alltid drar, \(ConsumptionInsightsBuilder.powerPhrase(baseloadKW))")
            }

            if let selected = selectedBar {
                RuleMark(x: .value("Vald timme", Double(selected.hour)))
                    .foregroundStyle(DS.Color.secondary.opacity(0.4))
                    .annotation(position: .top, spacing: DS.Spacing.xs, overflowResolution: ChartCalloutOverflow.resolution) {
                        ChartValueCallout(
                            title: "\(selected.hour)–\(selected.hour + 1)",
                            value: AppFormatters.kWh(selected.kWh)
                        )
                    }
            }
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: HistoryChartAxis.clockHourMarks) { value in
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisTick(length: 0)
                    .foregroundStyle(.tertiary)
                if let hour = value.as(Double.self) {
                    AxisValueLabel {
                        HistoryChartAxis.clockHourLabel(hour)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.precision(.fractionLength(0...1)))
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartXSelection(value: $selectedHour)
        .historyChartPlotStyle()
        .spriceChartMotion(profile.hours.map(\.kWh), selectedHour, profile.hours.filter(\.isCharging).map(\.hour))
        .frame(height: chartHeight)
        .zIndex(1)
        .accessibilityChartDescriptor(EVChargingChartDescriptor(profile: profile, summary: chartAccessibilityValue))
    }

    /// Consumption can not be negative, so the scale starts at zero.
    private var yMax: Double {
        let tallest = profile.hours.map { max($0.kWh, 0) }.max() ?? 0
        return max(tallest, baseloadKW ?? 0, 0.5) * 1.15
    }

    private func barStyle(for bar: ConsumptionEVHourBar) -> AnyShapeStyle {
        guard bar.isCharging else { return AnyShapeStyle(DS.Color.info) }
        // Striped when color alone must not carry the meaning.
        return differentiateWithoutColor ? AnyShapeStyle(ChargingHatch.paint) : AnyShapeStyle(DS.Color.warning)
    }

    private var selectedBar: ConsumptionEVHourBar? {
        guard let selectedHour else { return nil }
        let hour = Int(selectedHour.rounded())
        return profile.hours.first { $0.hour == hour }
    }

    private func barOpacity(for bar: ConsumptionEVHourBar) -> Double {
        guard let selectedHour else { return bar.isCharging ? 1 : 0.55 }
        return bar.hour == Int(selectedHour.rounded()) ? 1 : 0.35
    }

    private var chartAccessibilityValue: String {
        let charging = profile.hours.filter(\.isCharging)
        guard !charging.isEmpty else {
            return "Ingen laddning markerad den här dagen"
        }
        let first = charging[0].hour
        let last = charging[charging.count - 1].hour
        let energy = charging.reduce(0.0) { $0 + $1.kWh }
        return "Troligen laddning klockan \(first)–\(last + 1), \(AppFormatters.kWh(energy))"
    }
}

private struct ConsumptionInsightsHourChart: View {
    let diurnal: ConsumptionDiurnalInsight
    @State private var selectedHour: Double?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160

    var body: some View {
        Chart {
            ForEach(diurnal.hourBars) { bar in
                BarMark(
                    x: .value("Timme", Double(bar.hour)),
                    y: .value("kWh", bar.averageKWh)
                )
                .foregroundStyle(barColor(for: bar))
                .cornerRadius(HistoryChartAxis.barRadius)
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
            AxisMarks(values: HistoryChartAxis.clockHourMarks) { value in
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisTick(length: 0)
                    .foregroundStyle(.tertiary)
                if let hour = value.as(Double.self) {
                    AxisValueLabel {
                        HistoryChartAxis.clockHourLabel(hour)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: HistoryChartAxis.gridStroke)
                    .foregroundStyle(DS.Color.gridLine)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.precision(.fractionLength(0...1)))
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedHour)
        .historyChartPlotStyle()
        .spriceChartMotion(diurnal.hourBars.map(\.averageKWh), selectedHour)
        .frame(height: chartHeight)
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

// MARK: - Charging bars that do not depend on color

/// Orange bars with diagonal stripes. The stripes carry "troligen laddning" for
/// people who can not tell the colors apart, and they work in both appearances.
enum ChargingHatch {
    static let paint: ImagePaint = {
        let size = CGSize(width: 8, height: 8)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.93, green: 0.59, blue: 0.29, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.withAlphaComponent(0.55).setStroke()
            let path = UIBezierPath()
            path.lineWidth = 1.6
            path.move(to: CGPoint(x: -2, y: size.height + 2))
            path.addLine(to: CGPoint(x: size.width + 2, y: -2))
            path.move(to: CGPoint(x: -2, y: size.height * 2 + 2))
            path.addLine(to: CGPoint(x: size.width * 2 + 2, y: -2))
            path.move(to: CGPoint(x: -2 - size.width, y: size.height + 2))
            path.addLine(to: CGPoint(x: size.width + 2 - size.width, y: -2))
            path.stroke()
        }
        return ImagePaint(image: Image(uiImage: image), scale: 3)
    }()
}

private struct ChargingLegendSwatch: View {
    let isCharging: Bool
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Group {
            if isCharging {
                if differentiateWithoutColor {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(ChargingHatch.paint)
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(DS.Color.warning)
                }
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(DS.Color.info)
            }
        }
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }
}

/// Summary and Apple's audio graph for the hour-by-hour chart.
private struct EVChargingChartDescriptor: AXChartDescriptorRepresentable {
    let profile: ConsumptionEVDayProfile
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = profile.hours.map { String(format: "%02d", $0.hour) }
        let values = profile.hours.map { max($0.kWh, 0) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Klockslag", categoryOrder: labels)
        let upper = max(values.max() ?? 1, 0.1)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Kilowattimmar per timme",
            range: 0...upper,
            gridlinePositions: []
        ) { value in
            "\(value.formatted(.number.precision(.fractionLength(0...1)))) kilowattimmar"
        }
        let points = zip(profile.hours, values).map { bar, value in
            AXDataPoint(
                x: String(format: "%02d", bar.hour),
                y: value,
                additionalValues: [],
                label: bar.isCharging ? "Troligen laddning" : nil
            )
        }
        let series = AXDataSeriesDescriptor(name: "El per timme", isContinuous: false, dataPoints: points)
        return AXChartDescriptor(
            title: "El per timme under dygnet",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
