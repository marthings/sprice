import SwiftUI
import BorderBeam

struct HistoryMonthHeroSection: View {
    let snapshot: HistoryMonthSnapshot
    let comparison: HistoryMonthComparison?
    var previousMonthName: String? = nil
    let hasProvider: Bool
    var hasPastMonths: Bool = false
    var temperatureInsights: [TemperatureInsight] = []
    var priceArea: String? = nil
    var monthKey: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDetails = false
    @State private var savedBreakdown: MonthCostBreakdown?

    /// The split from the cost calculation when there is one, else from saved intervals.
    private var breakdown: MonthCostBreakdown? {
        if let parts = snapshot.costParts, let profile = snapshot.costProfile {
            return MonthCostBreakdown.make(parts: parts, profile: profile, kWh: snapshot.kWh)
        }
        return savedBreakdown
    }

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
                paragraphs: infoParagraphs,
                badge: snapshot.isCurrentMonth ? "Pågår" : nil,
                badgeAccessibilityLabel: "Månaden pågår"
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

            if let breakdown, snapshot.costKr != nil {
                detailsSection(breakdown)
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
#if DEBUG
        .onAppear {
            // `-OpenDetails` unfolds "Visa detaljer" for screenshots.
            if ProcessInfo.processInfo.arguments.contains("-OpenDetails") { showsDetails = true }
        }
#endif
        .task(id: "\(monthKey ?? "")-\(snapshot.costKr ?? 0)-\(snapshot.costParts == nil)") {
            await loadSavedBreakdown()
        }
    }

    // MARK: Details

    private func detailsSection(_ breakdown: MonthCostBreakdown) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Motion.curve(DS.Motion.reveal, reduceMotion: reduceMotion)) {
                    showsDetails.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(showsDetails ? "Dölj detaljer" : "Visa detaljer")
                        .font(DS.Font.semibold(14))
                        .foregroundStyle(DS.Color.accentText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.accentText)
                        .rotationEffect(.degrees(showsDetails ? 180 : 0))
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -DS.Spacing.xs)
            .accessibilityLabel("Detaljer om månadens kostnad")
            .accessibilityValue(showsDetails ? "Utfälld" : "Hopfälld")
            .accessibilityHint(showsDetails ? "Döljer uppdelningen" : "Visar vad kostnaden består av")
            .accessibilityAddTraits(.isButton)

            if showsDetails {
                detailRows(breakdown)
                    .transition(DS.Motion.revealTransition(reduceMotion: reduceMotion))
            }
        }
    }

    private func detailRows(_ breakdown: MonthCostBreakdown) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let kWh = breakdown.kWh, kWh > 0 {
                detailRow(title: "Förbrukning", value: AppFormatters.kWh(kWh), emphasized: false)
            }
            if let perKWh = breakdown.krPerKWh {
                detailRow(
                    title: "Snittpris",
                    value: "\(perKWh.formatted(.number.precision(.fractionLength(2)))) kr/kWh",
                    emphasized: false,
                    spoken: "\(perKWh.formatted(.number.precision(.fractionLength(2)))) kronor per kilowattimme"
                )
            }

            Divider()

            ForEach(breakdown.lines) { line in
                detailRow(
                    title: line.title,
                    value: "\(AppFormatters.wholeNumber(Double(line.wholeKr))) kr",
                    emphasized: false,
                    note: line.detail,
                    spoken: "\(AppFormatters.wholeNumber(Double(line.wholeKr))) kronor"
                )
            }

            Divider()

            detailRow(
                title: "Summa",
                value: "\(AppFormatters.wholeNumber(Double(breakdown.totalWholeKr))) kr",
                emphasized: true,
                spoken: "\(AppFormatters.wholeNumber(Double(breakdown.totalWholeKr))) kronor"
            )

            Text("Raderna är utan moms. Momsen står som en egen rad.")
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let note = breakdown.note {
                Text(note)
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailRow(
        title: String,
        value: String,
        emphasized: Bool,
        note: String? = nil,
        spoken: String? = nil
    ) -> some View {
        let titleFont = emphasized ? DS.Font.semibold(16) : DS.Font.callout
        let valueFont = emphasized ? DS.Font.semibold(16).monospacedDigit() : DS.Font.callout.monospacedDigit()
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(value)
                        .font(valueFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(value)
                        .font(valueFont)
                        .foregroundStyle(.primary)
                }
            }
            if let note {
                Text(note)
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(spoken ?? value)\(note.map { ". Innehåller \($0.lowercased())" } ?? "")")
    }

    @MainActor
    private func loadSavedBreakdown() async {
        guard snapshot.costParts == nil,
              let total = snapshot.costKr,
              let monthKey,
              let priceArea else {
            savedBreakdown = nil
            return
        }
        let intervals: [HistoricalEnergyIntervalValue]
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            intervals = ConsumptionInsightsSampleData.previewIntervals()
        } else {
            intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(monthKey: monthKey, priceArea: priceArea)) ?? []
        }
#else
        intervals = (try? EnergyHistoryQueryService().loadPreferredIntervals(monthKey: monthKey, priceArea: priceArea)) ?? []
#endif
        savedBreakdown = MonthCostBreakdown.make(
            intervals: intervals,
            retailContractType: snapshot.costProfile?.retailContractType ?? .spotPriceMarkup,
            displayedTotalKr: total
        )
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
        if breakdown != nil {
            parts.append("Under Visa detaljer ser du vad kostnaden består av: elen själv, elhandlarens påslag, elnätet, skatt och moms. Raderna ger summan ovan.")
            parts.append("Fasta avgifter räknas per timme, så en månad som pågår får bara sin del av dem.")
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
    var priceArea: String? = nil
    var currentMonthKey: String? = nil
    var previousMonthKey: String? = nil
    var throughDay: Int? = nil
    let previousMonthName: String?

    @State private var refinedSplit: HistoryPriceConsumptionSplit?

    private var shownSplit: HistoryPriceConsumptionSplit? {
        refinedSplit ?? split
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            if let split = shownSplit {
                SectionInfoHeader(
                    title: HistoryInsights.splitTitle(
                        consumptionEffectKr: split.consumptionEffectKr,
                        priceEffectKr: split.priceEffectKr
                    ),
                    paragraphs: splitInfoParagraphs
                )

                effectBar(
                    title: HistoryInsights.consumptionEffectLabel(split.consumptionEffectKr),
                    value: split.consumptionEffectKr,
                    maxMagnitude: maxMagnitude
                )
                if let spotEffect = split.spotEffectKr, let contractEffect = split.contractEffectKr {
                    effectBar(
                        title: HistoryInsights.spotEffectLabel(spotEffect),
                        value: spotEffect,
                        maxMagnitude: maxMagnitude
                    )
                    effectBar(
                        title: HistoryInsights.contractEffectLabel,
                        value: contractEffect,
                        maxMagnitude: maxMagnitude
                    )
                } else {
                    effectBar(
                        title: HistoryInsights.priceEffectLabel(split.priceEffectKr),
                        value: split.priceEffectKr,
                        maxMagnitude: maxMagnitude
                    )
                }

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
        .task(id: "\(currentMonthKey ?? "")-\(previousMonthKey ?? "")-\(throughDay ?? 0)-\(split?.priceEffectKr ?? 0)") {
            await refineSpotShare()
        }
    }

    /// The spot price on the month snapshots is an average per day or per month. The saved
    /// intervals give the price weighted by when the electricity was actually used.
    @MainActor
    private func refineSpotShare() async {
        guard let split, split.isSpotBased,
              let priceArea, let currentMonthKey, let previousMonthKey else {
            refinedSplit = nil
            return
        }
        let query = EnergyHistoryQueryService()
        guard let current = try? query.loadPreferredIntervals(monthKey: currentMonthKey, priceArea: priceArea),
              let previous = try? query.loadPreferredIntervals(monthKey: previousMonthKey, priceArea: priceArea),
              let currentSpot = Self.weightedSpot(current, throughDay: nil),
              let previousSpot = Self.weightedSpot(previous, throughDay: throughDay) else {
            refinedSplit = nil
            return
        }
        refinedSplit = split.refined(currentSpotOre: currentSpot, previousSpotOre: previousSpot)
    }

    private static func weightedSpot(_ intervals: [HistoricalEnergyIntervalValue], throughDay: Int?) -> Double? {
        let calendar = Calendar.energyHistory
        var kWh = 0.0
        var weighted = 0.0
        for interval in intervals {
            guard let used = interval.consumptionKWh, used > 0 else { continue }
            if let throughDay, calendar.component(.day, from: interval.intervalStart) > throughDay { continue }
            kWh += used
            weighted += used * interval.spotPriceOrePerKWh
        }
        return kWh > 0 ? weighted / kWh : nil
    }

    private var splitInfoParagraphs: [String] {
        var parts = [
            "Uppdelningen visar hur mycket som beror på att du använde mer eller mindre el, och hur mycket som beror på att priset ändrades.",
            "Jämförelsen gäller samma antal dagar, inte hela månaden, så länge den nya månaden inte är slut. Siffrorna följer senaste mätvärdet."
        ]
        if shownSplit?.spotEffectKr != nil {
            parts.append("Prisändringen delas i två. Spotpris är vad elen kostade på marknaden, med moms. Avtal och avgifter är resten: elhandlarens påslag, elnät, skatt och fasta avgifter.")
            parts.append("Ändrar du dina avgifter under Inställningar, eller byter elnätet pris, hamnar det under Avtal och avgifter.")
        }
        return parts
    }

    private var maxMagnitude: Double {
        guard let split = shownSplit else { return 1 }
        return max(
            abs(split.consumptionEffectKr),
            abs(split.priceEffectKr),
            abs(split.spotEffectKr ?? 0),
            abs(split.contractEffectKr ?? 0),
            1
        )
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
