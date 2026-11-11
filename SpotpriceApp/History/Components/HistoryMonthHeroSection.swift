import SwiftUI
import BorderBeam

struct HistoryMonthHeroSection: View {
    let snapshot: HistoryMonthSnapshot
    let comparison: HistoryMonthComparison?
    var previousMonthName: String? = nil
    let hasProvider: Bool
    var hasPastMonths: Bool = false
    var temperatureInsights: [TemperatureInsight] = []

    var body: some View {
        if snapshot.isCurrentMonth {
            card
                .borderBeam(
                    shape: .rounded(DS.Glass.cardRadius),
                    style: .small,
                    colors: BeamPalette.single(DS.Color.warning),
                    intensity: 0.45,
                    timing: BeamTiming(rotateDuration: 8)
                )
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Månadens siffror",
                paragraphs: infoParagraphs
            )

            if let cost = snapshot.costKr {
                heroValue(AppFormatters.wholeNumber(cost), unit: "kr", amount: cost)
                    .accessibilityLabel("Månadens kostnad \(AppFormatters.wholeNumber(cost)) kr")

                if let comparison {
                    Text(
                        HistoryInsights.comparisonSentence(
                            deltaKr: comparison.costDeltaKr,
                            previousMonthName: comparison.previousRangeLabel,
                            percent: comparison.percentChange
                        )
                    )
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                } else if let previousMonthName {
                    Text("Det går inte att jämföra med \(previousMonthName) än. Siffrorna för samma dagar saknas eller ser ofullständiga ut.")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let kWh = snapshot.kWh {
                heroValue(AppFormatters.kWhValue(kWh), unit: "kWh", amount: kWh)
                    .accessibilityLabel("Månadens förbrukning \(AppFormatters.kWh(kWh))")
                Text("Ingen kostnad sparad för den här månaden.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let spot = snapshot.spotOrePerKWh {
                heroValue(
                    (spot / 100).formatted(.number.precision(.fractionLength(2))),
                    unit: "kr/kWh",
                    amount: spot / 100
                )
                .accessibilityLabel("Snitt spotpris \((spot / 100).formatted(.number.precision(.fractionLength(2)))) kronor per kilowattimme")
                Text("Förbrukning saknas. Det här är bara spotpriset.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HistoryInsights.missingConsumptionMessage(hasProvider: hasProvider))
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(HistoryInsights.missingConsumptionMessage(hasProvider: hasProvider))
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(temperatureInsights) { insight in
                InsightRow(
                    icon: "thermometer.medium",
                    title: insight.title
                )
            }

            Text(snapshot.coverageText)
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
        }
        .spriceRevealMotion(temperatureInsights.map(\.id))
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var infoParagraphs: [String] {
        var parts: [String] = []
        if snapshot.isCurrentMonth {
            if snapshot.usedCurrentTariffs {
                parts.append("När månaden pågår visar siffrorna bara så långt den har hunnit. Kostnaden räknas med de priser och avgifter du har i dag.")
            } else {
                parts.append("När månaden pågår visar siffrorna bara så långt den har hunnit.")
            }
        } else if snapshot.usedCurrentTariffs {
            parts.append("Den sparade månadssumman saknas. Kostnaden är räknad med de priser och avgifter du har i dag.")
        }
        if hasPastMonths {
            parts.append("Äldre månader räknas med de priser och avgifter du har i dag, inte de som gällde då.")
        }
        if parts.isEmpty {
            parts.append("Här ser du månadens kostnad och hur den förhåller sig till förra perioden, så långt det finns mätvärden.")
        }
        if !temperatureInsights.isEmpty {
            for insight in temperatureInsights {
                parts.append(contentsOf: insight.details)
            }
            parts.append("Räknat på samma väder betyder att vi räknar bort skillnaden i temperatur, så att du ser om du själv använde mer eller mindre el.")
            parts.append("Bara uppvärmningen justeras. Det som går åt hela tiden, till exempel kyl, frys och lampor, räknas som det är.")
            parts.append("Det är en uppskattning, inte en mätning. Vi utgår bara från dygnets medeltemperatur och hur din förbrukning brukar följa den. Annat som också påverkar syns inte, till exempel elbil, att fler eller färre är hemma, varmvatten, semester och ändrade vanor.")
            parts.append("Uppskattningen blir grövre när din förbrukning följer vädret svagt, när vi har få dagar att räkna på eller när det saknas mätvärden för en del dagar. Då skriver vi ungefär, och när det inte går att räkna om visar vi bara förbrukningen som den är.")
            parts.append("När månaden pågår jämförs samma dagar i båda perioderna, efter det senaste mätvärdet.")
            parts.append("Temperaturen kommer från Open-Meteo för den ort du valt under Inställningar.")
        }
        return parts
    }

    /// The number never wraps. When number and unit do not fit side by side,
    /// as at large Dynamic Type sizes, the unit moves under the number.
    private func heroValue(_ value: String, unit: String, amount: Double) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                heroNumber(value, amount: amount)
                heroUnit(unit)
            }
            VStack(alignment: .leading, spacing: 0) {
                heroNumber(value, amount: amount, allowsShrink: true)
                heroUnit(unit)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func heroNumber(_ value: String, amount: Double, allowsShrink: Bool = false) -> some View {
        Text(value)
            .font(DS.Font.bold(48).monospacedDigit())
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(allowsShrink ? 0.6 : 1)
            .fixedSize(horizontal: !allowsShrink, vertical: false)
            .spriceNumericText(amount)
    }

    private func heroUnit(_ unit: String) -> some View {
        Text(unit)
            .font(DS.Font.callout)
            .fontWeight(.bold)
            .foregroundStyle(DS.Color.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct HistoryPriceConsumptionEffect: View {
    let split: HistoryPriceConsumptionSplit?
    let previousMonthName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            if let split {
                SectionInfoHeader(
                    title: HistoryInsights.splitTitle(
                        consumptionEffectKr: split.consumptionEffectKr,
                        priceEffectKr: split.priceEffectKr
                    ),
                    paragraphs: [
                        "Uppdelningen visar hur mycket som beror på att du använde mer eller mindre el, och hur mycket som beror på att priset ändrades.",
                        "Jämförelsen gäller samma antal dagar, inte hela månaden, så länge den nya månaden inte är slut. Siffrorna följer senaste mätvärdet."
                    ]
                )

                effectBar(
                    title: HistoryInsights.consumptionEffectLabel(split.consumptionEffectKr),
                    value: split.consumptionEffectKr,
                    maxMagnitude: maxMagnitude
                )
                effectBar(
                    title: HistoryInsights.priceEffectLabel(split.priceEffectKr),
                    value: split.priceEffectKr,
                    maxMagnitude: maxMagnitude
                )

                Text(HistoryInsights.splitSentence(
                    consumptionEffectKr: split.consumptionEffectKr,
                    priceEffectKr: split.priceEffectKr
                ))
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            } else if let previousMonthName {
                SectionInfoHeader(
                    title: "Därför blev det dyrare eller billigare",
                    paragraphs: [
                        "Uppdelningen visar hur mycket som beror på att du använde mer eller mindre el, och hur mycket som beror på att priset ändrades.",
                        "Jämförelsen gäller samma antal dagar när månaden inte är slut."
                    ]
                )
                Text("Det går inte att jämföra med \(previousMonthName) än. Förbrukning eller kostnad för samma dagar saknas eller ser ofullständig ut.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var maxMagnitude: Double {
        guard let split else { return 1 }
        return max(abs(split.consumptionEffectKr), abs(split.priceEffectKr), 1)
    }

    private func effectBar(title: String, value: Double, maxMagnitude: Double) -> some View {
        let amount = HistoryInsights.signedKr(value)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(title)
                        .font(DS.Font.callout)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(amount)
                        .font(DS.Font.semibold(14).monospacedDigit())
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Font.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(amount)
                        .font(DS.Font.semibold(14).monospacedDigit())
                }
            }

            GeometryReader { geometry in
                let width = geometry.size.width * CGFloat(abs(value) / maxMagnitude)
                RoundedRectangle(cornerRadius: 4)
                    .fill(value >= 0 ? DS.Color.danger : DS.Color.success)
                    .frame(width: max(width, value == 0 ? 0 : 8), height: 12)
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(amount)")
    }
}

struct HistoryPaidVersusSpot: View {
    let snapshot: HistoryMonthSnapshot
    var priceArea: String? = nil
    var costProfile: CostProfile? = nil
    var monthKey: String? = nil

    @State private var comparison: CostUsageInsights.FixedComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Betalt pris och spot",
                paragraphs: infoParagraphs
            )

            if let paid = snapshot.paidKrPerKWh {
                labeledAmount(
                    title: "Du betalade",
                    value: paid,
                    unit: "kr/kWh",
                    fractionLength: 2
                )
            }

            if let spotKr = snapshot.spotKrPerKWh {
                labeledAmount(
                    title: "Spotpris i snitt",
                    value: spotKr,
                    unit: "kr/kWh",
                    fractionLength: 2
                )
            } else if snapshot.paidKrPerKWh == nil {
                Text("Varken betalt pris eller spotpris finns sparat för den här månaden.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let comparison {
                InsightRow(icon: "arrow.left.arrow.right", title: comparison.title)
            }
        }
        .spriceRevealMotion(comparison?.title ?? "")
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
        .task(id: "\(monthKey ?? "")-\(priceArea ?? "")-\(ConsumptionSettings.shared.compareFixedPriceOrePerKWh)") {
            await loadComparison()
        }
    }

    private var infoParagraphs: [String] {
        var parts = [
            "Du betalade är vad kilowattimmen kostade i snitt, med allt inräknat. Spot i snitt är börsens elpris, utan påslag, nät, skatt och moms.",
            "Båda siffrorna är i kronor per kilowattimme (kr/kWh)."
        ]
        if let comparison {
            parts.append(comparison.title)
            parts.append("Jämförelsen gäller bara elhandeln den här månaden, mot det fasta pris du angett under Inställningar.")
        }
        return parts
    }

    @MainActor
    private func loadComparison() async {
        guard let monthKey, let priceArea, let costProfile else {
            comparison = nil
            return
        }
        let intervals: [HistoricalEnergyIntervalValue]
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            intervals = ConsumptionInsightsSampleData.previewIntervals()
        } else {
            intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(
                monthKey: monthKey,
                priceArea: priceArea
            )) ?? []
        }
#else
        intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(
            monthKey: monthKey,
            priceArea: priceArea
        )) ?? []
#endif
        let fixedOre = ConsumptionSettings.shared.compareFixedPriceOrePerKWh
        comparison = CostUsageInsights.fixedComparison(
            intervals: intervals,
            profile: costProfile,
            fixedOrePerKWh: fixedOre > 0 ? fixedOre : CostUsageInsights.defaultFixedPriceOrePerKWh
        )
    }

    private func labeledAmount(title: String, value: Double, unit: String, fractionLength: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: DS.Spacing.sm)
                labeledNumber(value, fractionLength: fractionLength)
                labeledUnit(unit)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    labeledNumber(value, fractionLength: fractionLength)
                    labeledUnit(unit)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(unit)")
    }

    private func labeledNumber(_ value: Double, fractionLength: Int) -> some View {
        Text(value, format: .number.precision(.fractionLength(fractionLength)))
            .font(DS.Font.semibold(20).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .spriceNumericText(value)
    }

    private func labeledUnit(_ unit: String) -> some View {
        Text(unit)
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
