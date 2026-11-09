import SwiftUI

struct HistoryMonthHeroSection: View {
    let snapshot: HistoryMonthSnapshot
    let comparison: HistoryMonthComparison?
    let hasProvider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let cost = snapshot.costKr {
                heroValue(AppFormatters.wholeNumber(cost), unit: "kr")
                    .accessibilityLabel("Månadens kostnad \(AppFormatters.wholeNumber(cost)) kr")

                if let comparison {
                    Text(
                        HistoryInsights.comparisonSentence(
                            deltaKr: comparison.costDeltaKr,
                            previousMonthName: AppFormatters.monthName(comparison.previous.summary.periodStart),
                            percent: comparison.percentChange
                        )
                    )
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else if let kWh = snapshot.kWh {
                heroValue(AppFormatters.kWhValue(kWh), unit: "kWh")
                    .accessibilityLabel("Månadens förbrukning \(AppFormatters.kWh(kWh))")
                Text("Ingen kostnad sparad för den här månaden.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let spot = snapshot.spotOrePerKWh {
                heroValue(AppFormatters.oreValue(spot), unit: "öre/kWh")
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

            Text(snapshot.coverageText)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)

            if snapshot.isCurrentMonth {
                Text(
                    snapshot.usedCurrentTariffs
                        ? "Pågående månad. Kostnaden är räknad med dina nuvarande tariffer, och bara så långt månaden har hunnit."
                        : "Pågående månad. Siffrorna visar bara så långt månaden har hunnit."
                )
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else if snapshot.usedCurrentTariffs {
                Text("Den sparade månadssumman saknas. Kostnaden är räknad med dina nuvarande tariffer.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func heroValue(_ value: String, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Font.bold(48).monospacedDigit())
                .foregroundStyle(.primary)
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let split {
                Text(HistoryInsights.splitTitle(
                    consumptionEffectKr: split.consumptionEffectKr,
                    priceEffectKr: split.priceEffectKr
                ))
                .font(DS.Font.headline)

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
                Text("Därför blev det dyrare eller billigare")
                    .font(DS.Font.headline)
                Text("Uppdelningen kräver förbrukning och kostnad för både den här månaden och \(previousMonthName). Den saknas, så jämförelsen visas inte.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let paid = snapshot.paidKrPerKWh {
                labeledAmount(
                    title: "Du betalade",
                    value: paid,
                    unit: "kr/kWh",
                    fractionLength: 2
                )
            }

            if let spotKr = snapshot.spotKrPerKWh, let spotOre = snapshot.spotOrePerKWh {
                labeledAmount(
                    title: "Spot i snitt",
                    value: spotKr,
                    unit: "kr/kWh",
                    fractionLength: 2
                )
                Text("Det är \(AppFormatters.oreValue(spotOre)) öre/kWh. Spot är utan påslag, nät, skatt och moms.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if snapshot.paidKrPerKWh == nil {
                Text("Varken betalt pris eller spotpris finns sparat för den här månaden.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private func labeledAmount(title: String, value: Double, unit: String, fractionLength: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: DS.Spacing.sm)
            Text(value, format: .number.precision(.fractionLength(fractionLength)))
                .font(DS.Font.semibold(20).monospacedDigit())
            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value.formatted(.number.precision(.fractionLength(fractionLength)))) \(unit)")
    }
}
