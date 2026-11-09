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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var regularDonutSize: CGFloat = 208
    @ScaledMetric(relativeTo: .title) private var compactDonutSize: CGFloat = 118
    @ScaledMetric(relativeTo: .largeTitle) private var regularPriceSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title) private var compactPriceSize: CGFloat = 20

    private var usesExternalHeroPrice: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? DS.Spacing.sm : DS.Spacing.md) {
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

            Text("Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let missingGridMessage = breakdown.missingGridMessage {
                Label(missingGridMessage, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(style == .compact ? DS.Spacing.md : DS.Spacing.lg)
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
            }

            if !usesExternalHeroPrice {
                centerPrice
                    .frame(width: donutSize * 0.54)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: donutSize, height: donutSize)
        .accessibilityElement(children: .contain)
    }

    private var centerPrice: some View {
        let priceColor = priceCategory.map { DS.Color.forCategory($0) } ?? .primary

        return VStack(spacing: DS.Spacing.xxs) {
            if style == .regular, let priceCategory {
                PriceLevelBadge(category: priceCategory)
            }

            Text("Nu")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)

            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                Text(breakdown.totalKrPerKWh, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(style == .compact ? compactPriceSize : regularPriceSize).monospacedDigit())
                    .foregroundStyle(priceColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if style == .regular {
                    PriceChangeIndicator(
                        current: breakdown.totalKrPerKWh,
                        next: nextTotalKrPerKWh,
                        fontSize: 14
                    )
                }
            }

            Text("kr/kWh")
                .font(style == .compact ? DS.Font.micro : DS.Font.caption)
                .foregroundStyle(DS.Color.secondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(centerAccessibilityLabel)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(breakdown.lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(color(for: line.kind))
                        .frame(width: 8, height: 8)
                        .padding(.top, 3)
                        .accessibilityHidden(true)

                    Text(line.title)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: DS.Spacing.sm)

                    Text(shareText(for: line))
                        .font(DS.Font.micro.monospacedDigit())
                        .foregroundStyle(DS.Color.secondary)
                        .frame(minWidth: 32, alignment: .trailing)

                    Text(line.amountOrePerKWh, format: .number.precision(.fractionLength(1)))
                        .font(DS.Font.micro.monospacedDigit())
                        .foregroundStyle(.primary)

                    Text("öre")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(legendAccessibilityLabel(for: line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        "\(Int(sharePercent(for: line).rounded())) %"
    }

    private func sectorAccessibilityValue(for line: KilowattHourLine) -> String {
        "\(Int(sharePercent(for: line).rounded())) procent, \(line.amountOrePerKWh.formatted(.number.precision(.fractionLength(1)))) öre per kilowattimme"
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
        }
    }
}
