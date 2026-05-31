import SwiftUI

struct MonthlyConsumptionSection: View {
    let consumption: ConsumptionData?
    let powerPeaks: [PowerPeak]
    let consumptionError: String?
    let isConfigured: Bool
    let averagePrice: Double
    let preciseCost: PreciseMonthlyCost?
    let profile: CostProfile
    let historySummary: HistoricalEnergySummaryValue?
    var onConfigureConsumption: () -> Void = {}

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let consumption {
            consumptionContent(consumption)
        } else if let historySummary {
            historyContent(historySummary)
        } else if let consumptionError {
            AppStatusRow(
                icon: "exclamationmark.triangle.fill",
                title: "Kunde inte hämta förbrukning",
                message: consumptionError,
                color: DS.Color.warning
            )
            .padding(.vertical, DS.Spacing.sm)
        } else if !isConfigured {
            Button(action: onConfigureConsumption) {
                AppStatusRow(
                    icon: "gearshape.fill",
                    title: "Konfigurera förbrukning",
                    message: "Lägg till dina uppgifter för att se månadsstatistik.",
                    color: DS.Color.secondary,
                    trailingIcon: "chevron.right"
                )
                .padding(.vertical, DS.Spacing.sm)
            }
            .buttonStyle(.plain)
        } else {
            AppStatusRow(
                icon: "hourglass",
                title: "Förbrukning laddas",
                message: "Månadsstatistik visas när den är tillgänglig.",
                color: DS.Color.secondary
            )
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func historyContent(_ summary: HistoricalEnergySummaryValue) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Sparad historik")
                    .font(DS.Font.headline)
                Spacer(minLength: DS.Spacing.sm)
                HistoryCoverageBadge(coverage: summary.dataCoverage)
            }

            HStack(spacing: DS.Spacing.sm) {
                summaryCard(
                    title: "Förbrukning",
                    value: summary.totalConsumptionKWh.map { AppFormatters.kWhValue($0) } ?? "-",
                    unit: "kWh",
                    icon: "bolt.fill",
                    color: .primary
                )
                .padding(DS.Spacing.lg)
                .glassCard(cornerRadius: DS.Radius.lg)

                summaryCard(
                    title: summary.totalCostSEK == nil ? "Snitt spotpris" : "Kostnad",
                    value: historyCostValue(summary),
                    unit: summary.totalCostSEK == nil ? "öre" : "kr",
                    icon: "wallet.bifold.fill",
                    color: .primary
                )
                .padding(DS.Spacing.lg)
                .glassCard(cornerRadius: DS.Radius.lg)
            }

            Label(summary.coverageText(style: .brandedMonthly), systemImage: "clock.arrow.circlepath")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: DS.Radius.lg)
        }
    }

    private func consumptionContent(_ consumption: ConsumptionData) -> some View {
        let enhancedCost = monthlyCost(for: consumption)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(consumption.monthName.capitalized)
                .font(DS.Font.headline)
            HStack(spacing: DS.Spacing.sm) {
                summaryCard(
                    title: "Förbrukning",
                    value: AppFormatters.wholeNumber(consumption.totalKWh),
                    unit: "kWh",
                    icon: "bolt.fill",
                    color: .primary
                )
                .padding(DS.Spacing.lg)
                .glassCard(cornerRadius: DS.Radius.lg)
                summaryCard(
                    title: preciseCost == nil ? "Uppskattat" : "Kostnad",
                    value: AppFormatters.wholeNumber(enhancedCost.totalKr),
                    unit: "kr",
                    icon: "wallet.bifold.fill",
                    color: .primary
                )
                .padding(DS.Spacing.lg)
                .glassCard(cornerRadius: DS.Radius.lg)
            }

            costBreakdown(enhancedCost)

            if !powerPeaks.isEmpty {
                powerPeaksSection
            }
        }
    }

    private func summaryCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        MetricCard(
            title: title,
            value: value,
            unit: unit,
            icon: icon,
            color: color
        )
        .padding(.vertical, DS.Spacing.sm)
    }

    private func costBreakdown(_ cost: EnhancedCost) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Kostnadsdelar")
                .font(DS.Font.headline)

            VStack(spacing: DS.Spacing.xs) {
                SharedCostBreakdownRow(
                    label: "Elhandel",
                    amount: cost.providerTotalKr,
                    color: DS.Color.warning,
                    style: .regular
                )
                SharedCostBreakdownRow(
                    label: "Elnät",
                    amount: cost.gridTotalKr,
                    color: DS.Color.info,
                    style: .regular
                )
                SharedCostBreakdownRow(
                    label: "Skatt och avgifter",
                    amount: cost.taxesAndFeesKr,
                    color: DS.Color.secondary,
                    style: .regular
                )
            }
            
            if let preciseCost {
                CostPrecisionNote(cost: preciseCost)
                
            } else if profile.confidence == .estimated {
                Label("Uppskattningen förbättras när elhandelsavtal och elnätsuppgifter är ifyllda.", systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    private var powerPeaksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Effekttoppar")
                .font(DS.Font.headline)

            ForEach(powerPeaks.prefix(3)) { peak in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.danger)
                        .frame(width: 20)
                    Text(powerPeakDateLabel(for: peak.date))
                        .font(DS.Font.callout)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(peak.kW, format: .number.precision(.fractionLength(1)))
                        .font(DS.Font.semibold(14).monospacedDigit())
                    Text("kW")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    private func powerPeakDateLabel(for date: Date) -> String {
        AppFormatters.powerPeakHourLabel(date)
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

    private func historyCostValue(_ summary: HistoricalEnergySummaryValue) -> String {
        if let cost = summary.totalCostSEK {
            return AppFormatters.wholeNumber(cost)
        }
        if let price = summary.averageSpotPriceOrePerKWh {
            return AppFormatters.oreValue(price)
        }
        return "-"
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
        profile: .swedishDefaultEstimate(),
        historySummary: nil
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
