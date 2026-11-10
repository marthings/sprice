import SwiftUI
import Charts

enum KilowattHourBreakdownStyle {
    case regular
    case compact
}

struct KilowattHourBreakdownView: View {
    let breakdown: KilowattHourBreakdown
    var style: KilowattHourBreakdownStyle = .regular
    var priceCategory: PriceCategory?
    var nextTotalKrPerKWh: Double?
    var insights: [CardInsight] = []
    var extraInfoParagraphs: [String] = []
    var onInsightTap: ((CardInsight) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var regularDonutSize: CGFloat = 208
    @ScaledMetric(relativeTo: .title) private var compactDonutSize: CGFloat = 118
    @ScaledMetric(relativeTo: .largeTitle) private var regularPriceSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title) private var compactPriceSize: CGFloat = 20

    private var usesExternalHeroPrice: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            if style == .regular {
                SectionInfoHeader(
                    title: "Vad en kWh kostar",
                    paragraphs: infoParagraphs
                )
            }

            if style == .regular {
                ChartCaption("Så fördelas priset på en kWh, i kronor per kWh")
            }

            if usesExternalHeroPrice {
                centerPrice
                    .frame(maxWidth: .infinity)
            }

            if style == .compact && !usesExternalHeroPrice {
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    donutChart
                    legend
                }
            } else {
                donutChart
                    .frame(maxWidth: .infinity)
                legend
            }

            if let missingGridMessage = breakdown.missingGridMessage {
                Label(missingGridMessage, systemImage: "info.circle.fill")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(insights) { insight in
                        if onInsightTap != nil {
                            Button {
                                onInsightTap?(insight)
                            } label: {
                                InsightRow(
                                    icon: insight.icon,
                                    title: insight.title,
                                    detail: insight.detail,
                                    showsChevron: insight.showsChevron
                                )
                            }
                            .buttonStyle(SpriceCardPressButtonStyle())
                        } else {
                            InsightRow(
                                icon: insight.icon,
                                title: insight.title,
                                detail: insight.detail,
                                showsChevron: insight.showsChevron
                            )
                        }
                    }
                }
            }
        }
        .spriceRevealMotion(insights.map(\.id))
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .accent)
        .accessibilityElement(children: .contain)
    }

    private var donutSize: CGFloat {
        let raw = style == .compact ? compactDonutSize : regularDonutSize
        return min(max(raw, style == .compact ? 96 : 168), style == .compact ? 148 : 260)
    }

    private var donutChart: some View {
        ZStack {
            if breakdown.lines.isEmpty {
                Circle()
                    .stroke(DS.Color.outline, lineWidth: style == .compact ? 12 : 18)
                    .frame(width: donutSize * 0.82, height: donutSize * 0.82)
                    .accessibilityHidden(true)
            } else {
                Chart(breakdown.lines) { line in
                    SectorMark(
                        angle: .value("Andel", line.amountKrPerKWh),
                        innerRadius: .ratio(style == .compact ? 0.58 : 0.64),
                        angularInset: style == .compact ? 1.4 : 2.0
                    )
                    .cornerRadius(style == .compact ? 2.5 : 4)
                    .foregroundStyle(color(for: line.kind))
                    .accessibilityLabel(line.title)
                    .accessibilityValue(sectorAccessibilityValue(for: line))
                }
                .chartLegend(.hidden)
                .spriceChartMotion(breakdown.lines.map(\.amountKrPerKWh))
            }

            if !usesExternalHeroPrice {
                centerPrice
                    .frame(width: donutSize * 0.54)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: donutSize, height: donutSize)
        .padding(.top, 0)
        .accessibilityElement(children: .contain)
    }

    private var centerPrice: some View {
        let priceColor = priceCategory.map { DS.Color.textForCategory($0) } ?? .primary

        return VStack(spacing: DS.Spacing.xxs) {
            if style == .regular, let priceCategory {
                PriceLevelBadge(category: priceCategory)
            }

            Text("Just nu")
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)

            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                Text(breakdown.totalKrPerKWh, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(style == .compact ? compactPriceSize : regularPriceSize).monospacedDigit())
                    .foregroundStyle(priceColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .spriceNumericText(breakdown.totalKrPerKWh)

                if style == .regular {
                    PriceChangeIndicator(
                        current: breakdown.totalKrPerKWh,
                        next: nextTotalKrPerKWh,
                        fontSize: 14
                    )
                }
            }

            Text("kr/kWh")
                .font(style == .compact ? DS.Font.footnote : DS.Font.caption)
                .foregroundStyle(DS.Color.secondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(centerAccessibilityLabel)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(breakdown.lines) { line in
                legendRow(line)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(legendAccessibilityLabel(for: line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func legendRow(_ line: KilowattHourLine) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            legendStackedRow(line)
        } else {
            ViewThatFits(in: .horizontal) {
                legendInlineRow(line)
                legendStackedRow(line)
            }
        }
    }

    private func legendDot(_ line: KilowattHourLine) -> some View {
        Circle()
            .fill(color(for: line.kind))
            .frame(width: 8, height: 8)
            .padding(.top, 3)
            .accessibilityHidden(true)
    }

    private func legendTitle(_ line: KilowattHourLine) -> some View {
        Text(line.title)
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func legendDetail(_ line: KilowattHourLine) -> some View {
        if let detail = line.detail {
            Text(detail)
                .font(DS.Font.footnote)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
        }
    }

    private func legendInlineRow(_ line: KilowattHourLine) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                legendDot(line)
                legendTitle(line)

                Spacer(minLength: DS.Spacing.sm)

                Text(shareText(for: line))
                    .font(DS.Font.footnote.monospacedDigit())
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 32, alignment: .trailing)

                Text(AppFormatters.krPerKWh(line.amountKrPerKWh))
                    .font(DS.Font.footnote.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            legendDetail(line)
        }
    }

    private func legendStackedRow(_ line: KilowattHourLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            legendDot(line)
            VStack(alignment: .leading, spacing: 0) {
                legendTitle(line)
                if let detail = line.detail {
                    Text(detail)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(shareText(for: line)), \(AppFormatters.krPerKWh(line.amountKrPerKWh))")
                    .font(DS.Font.footnote.monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
    }

    private var infoParagraphs: [String] {
        var parts = [
            "Cirkeln och listan visar vad en kilowattimme (kWh) kostar just nu, uppdelat på elhandel, elnät, skatt och annat. Allt anges i kronor per kWh.",
            "Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar."
        ]
        if let folded = breakdown.lines.first(where: { $0.kind == .other }), let detail = folded.detail {
            parts.append("Annat smått är poster som är under 2 procent av priset var för sig: \(detail.lowercased()).")
        }
        if let missingGridMessage = breakdown.missingGridMessage {
            parts.append(missingGridMessage)
        }
        parts.append(contentsOf: extraInfoParagraphs)
        return parts
    }

    private var centerAccessibilityLabel: String {
        var parts = [
            "Nu",
            AppFormatters.krPerKWh(breakdown.totalKrPerKWh)
        ]
        if let priceCategory {
            parts.insert(priceCategory.label, at: 0)
        }
        return parts.joined(separator: ", ")
    }

    private func sharePercent(for line: KilowattHourLine) -> Double {
        guard breakdown.totalKrPerKWh > 0 else { return 0 }
        return (line.amountKrPerKWh / breakdown.totalKrPerKWh) * 100
    }

    private func shareText(for line: KilowattHourLine) -> String {
        let percent = sharePercent(for: line)
        if percent > 0, percent < 1 { return "<1 %" }
        return "\(Int(percent.rounded())) %"
    }

    private func sectorAccessibilityValue(for line: KilowattHourLine) -> String {
        "\(Int(sharePercent(for: line).rounded())) procent, \(line.amountKrPerKWh.formatted(.number.precision(.fractionLength(2)))) kronor per kilowattimme"
    }

    private func legendAccessibilityLabel(for line: KilowattHourLine) -> String {
        "\(line.title), \(sectorAccessibilityValue(for: line))"
    }

    private func color(for kind: KilowattHourLineKind) -> Color {
        switch kind {
        case .retailEnergy:
            return DS.Color.info
        case .markup:
            return DS.Color.brand
        case .gridTransfer:
            return DS.Color.warning
        case .energyTax:
            return DS.Color.success
        case .certificates:
            return Color.purple
        case .monthlyFees:
            return Color.orange
        case .powerTariff:
            return DS.Color.danger
        case .vat:
            return Color.gray
        case .other:
            return Color.teal
        }
    }
}
