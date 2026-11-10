import SwiftUI

struct HistoryMonthHeroSection: View {
    let snapshot: HistoryMonthSnapshot
    let comparison: HistoryMonthComparison?
    var previousMonthName: String? = nil
    let hasProvider: Bool
    var hasPastMonths: Bool = false
    var temperatureInsights: [TemperatureInsight] = []

    var body: some View {
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
                heroValue(AppFormatters.oreValue(spot), unit: "öre/kWh", amount: spot)
                    .accessibilityLabel("Snitt spotpris \(AppFormatters.ore(spot)) per kilowattimme")
                Text("Förbrukning saknas. Det här är bara spotpriset.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HistoryInsights.missingConsumptionMessage(hasProvider: hasProvider))
                    .font(DS.Font.micro)
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
                    title: insight.title,
                    detail: insight.isUncertain ? "Osäker jämförelse" : nil
                )
            }

            Text(snapshot.coverageText)
                .font(DS.Font.micro)
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
                parts.append(insight.title)
            }
            parts.append("Jämförelsen tar hänsyn till om det varit kallare eller varmare. Bara uppvärmningen justeras, inte det som huset drar hela tiden.")
            parts.append("Beräkningen bygger på det senaste mätvärdet och jämför samma antal dagar i båda perioderna.")
            parts.append("Om det finns för lite underlag, eller om förbrukningen inte följer vädret tydligt, visas ingen justering.")
            parts.append("Temperaturen kommer från Open-Meteo för den ort du valt under Inställningar.")
        }
        return parts
    }

    private func heroValue(_ value: String, unit: String, amount: Double) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Font.bold(48).monospacedDigit())
                .foregroundStyle(.primary)
                .spriceNumericText(amount)
            Text(unit)
                .font(DS.Font.callout)
                .fontWeight(.bold)
                .foregroundStyle(DS.Color.secondary)
        }
        .accessibilityElement(children: .combine)
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
            HStack {
                Text(title)
                    .font(DS.Font.callout)
                Spacer(minLength: DS.Spacing.sm)
                Text(amount)
                    .font(DS.Font.semibold(14).monospacedDigit())
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
                    title: "Spot i snitt",
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
            "Spotpriset visas i kronor, och samma siffra i öre per kilowattimme."
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
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: DS.Spacing.sm)
            Text(value, format: .number.precision(.fractionLength(fractionLength)))
                .font(DS.Font.semibold(20).monospacedDigit())
                .spriceNumericText(value)
            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(unit)")
    }
}
