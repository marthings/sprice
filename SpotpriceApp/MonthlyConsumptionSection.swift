import SwiftUI

struct MonthlyConsumptionSection: View {
    let consumption: ConsumptionData?
    let powerPeaks: [PowerPeak]
    let consumptionError: String?
    let isConfigured: Bool
    let averagePrice: Double
    let preciseCost: PreciseMonthlyCost?
    let profile: CostProfile
    var onConfigureConsumption: () -> Void = {}

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Förbrukning")
                .font(DS.Font.headline)

            content
        }
        .padding(DS.Spacing.lg)
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    @ViewBuilder
    private var content: some View {
        if let consumption {
            consumptionContent(consumption)
        } else if let consumptionError {
            statusRow(
                icon: "exclamationmark.triangle.fill",
                title: "Kunde inte hämta förbrukning",
                message: consumptionError,
                color: DS.Color.warning
            )
        } else if !isConfigured {
            Button(action: onConfigureConsumption) {
                statusRow(
                    icon: "gearshape.fill",
                    title: "Konfigurera förbrukning",
                    message: "Lägg till dina uppgifter för att se månadsstatistik.",
                    color: .secondary,
                    trailingIcon: "chevron.right"
                )
            }
            .buttonStyle(.plain)
        } else {
            statusRow(
                icon: "hourglass",
                title: "Förbrukning laddas",
                message: "Månadsstatistik visas när den är tillgänglig.",
                color: .secondary
            )
        }
    }

    private func consumptionContent(_ consumption: ConsumptionData) -> some View {
        let enhancedCost = monthlyCost(for: consumption)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(consumption.monthName.capitalized)
                    .font(DS.Font.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let preciseCost {
                    Text("\(preciseCost.matchedIntervals)/\(preciseCost.totalIntervals) intervall")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                summaryCard(
                    title: "Förbrukning",
                    value: Int(consumption.totalKWh.rounded()).formatted(),
                    unit: "kWh",
                    icon: "bolt.fill",
                    color: DS.Color.warning
                )
                summaryCard(
                    title: preciseCost == nil ? "Uppskattat" : "Kostnad",
                    value: Int(enhancedCost.totalKr.rounded()).formatted(),
                    unit: "kr",
                    icon: "creditcard.fill",
                    color: DS.Color.info
                )
            }

            costBreakdown(enhancedCost)

            if let preciseCost {
                precisionNote(preciseCost)
            } else if profile.confidence == .estimated {
                Label("Uppskattningen förbättras när elhandelsavtal och elnätsuppgifter är ifyllda.", systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !powerPeaks.isEmpty {
                powerPeaksSection
            }
        }
    }

    private func summaryCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(20).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(unit)
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func costBreakdown(_ cost: EnhancedCost) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Kostnadsdelar")
                .font(DS.Font.semibold(13))

            VStack(spacing: DS.Spacing.xs) {
                costRow("Elhandel", cost.providerTotalKr, color: DS.Color.warning)
                costRow("Elnät", cost.gridTotalKr, color: DS.Color.info)
                costRow("Skatt och avgifter", cost.taxesAndFeesKr, color: .secondary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private func costRow(_ title: String, _ value: Double, color: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(DS.Font.callout)
            Spacer(minLength: DS.Spacing.sm)
            Text(value, format: .number.precision(.fractionLength(0)))
                .font(DS.Font.semibold(14).monospacedDigit())
            Text("kr")
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
        }
    }

    private func precisionNote(_ cost: PreciseMonthlyCost) -> some View {
        let ratio = cost.totalIntervals > 0 ? Double(cost.matchedIntervals) / Double(cost.totalIntervals) : 0
        let percent = ratio.formatted(.percent.precision(.fractionLength(0)))

        return Label("Beräknat från faktisk förbrukning och matchade spotpriser: \(percent).", systemImage: "checkmark.seal.fill")
            .font(DS.Font.micro)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var powerPeaksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Effekttoppar")
                .font(DS.Font.semibold(13))

            ForEach(powerPeaks.prefix(3)) { peak in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.danger)
                        .frame(width: 20)
                    Text(peak.date.formatted(.dateTime.day().month(.abbreviated).hour()))
                        .font(DS.Font.callout)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(peak.kW, format: .number.precision(.fractionLength(1)))
                        .font(DS.Font.semibold(14).monospacedDigit())
                    Text("kW")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private func statusRow(icon: String, title: String, message: String, color: Color, trailingIcon: String? = nil) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.callout)
                Text(message)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private func monthlyCost(for consumption: ConsumptionData) -> EnhancedCost {
        if let preciseCost {
            return totalCostService.calculateTotalCost(
                kWh: preciseCost.totalKWh,
                spotPriceOre: preciseCost.totalKWh > 0 ? (preciseCost.totalCostKr / preciseCost.totalKWh) * 100 : averagePrice,
                profile: profile,
                hoursInPeriod: 730
            )
        }

        return totalCostService.calculateTotalCost(
            kWh: consumption.totalKWh,
            spotPriceOre: averagePrice,
            profile: profile,
            hoursInPeriod: 730
        )
    }
}

#Preview {
    MonthlyConsumptionSection(
        consumption: ConsumptionData(
            totalKWh: 873,
            values: [],
            meterName: "Hem",
            meterId: "123",
            monthDate: Date()
        ),
        powerPeaks: [
            PowerPeak(date: Date(), kW: 6.8),
            PowerPeak(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), kW: 5.9)
        ],
        consumptionError: nil,
        isConfigured: true,
        averagePrice: 72,
        preciseCost: PreciseMonthlyCost(totalCostKr: 1420, totalKWh: 873, matchedIntervals: 820, totalIntervals: 873),
        profile: .swedishDefaultEstimate()
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
