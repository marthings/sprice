import SwiftUI

struct HistoryMonthSummaryCards: View {
    let summary: HistoricalEnergySummaryValue
    let costProfile: CostProfile
    let isCurrentMonth: Bool
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                let displayedConsumption = liveMonthlyConsumption?.totalKWh ?? summary.totalConsumptionKWh
                let displayedCost = currentMonthCostUsingLiveData ?? (isCurrentMonth ? liveCostForCurrentMonth : summary.totalCostSEK)

                MetricCard(
                    title: isCurrentMonth ? "Kostnad (aktuella tariffer)" : "Kostnad",
                    value: displayedCost.map { AppFormatters.wholeNumber($0) } ?? "-",
                    unit: "kr",
                    icon: "wallet.bifold.fill",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard()

                MetricCard(
                    title: "Förbrukning",
                    value: displayedConsumption.map { AppFormatters.kWhValue($0) } ?? "-",
                    unit: "kWh",
                    icon: "bolt.fill",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard()
            }

            HStack(spacing: DS.Spacing.sm) {
                let averagePriceMetric = averagePriceMetric(
                    summary,
                    liveCost: currentMonthCostUsingLiveData ?? (isCurrentMonth ? liveCostForCurrentMonth : nil)
                )
                MetricCard(
                    title: averagePriceMetric.title,
                    value: averagePriceMetric.value,
                    unit: averagePriceMetric.unit,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard()
            }

            if isCurrentMonth {
                Text("Pågående månad. Använder aktuella tariffer och senaste mätdata")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
    }

    private var currentMonthCostUsingLiveData: Double? {
        guard isCurrentMonth else { return nil }

        let consumption = liveMonthlyConsumption
        let preciseCost = livePreciseCost
        let averagePrice = summary.averageSpotPriceOrePerKWh ?? 0

        if let consumption {
            if let precise = preciseCost {
                let effectiveSpotOre = precise.totalKWh > 0
                    ? (precise.totalCostKr / precise.totalKWh) * 100
                    : averagePrice
                return totalCostService.calculateTotalCost(
                    kWh: precise.totalKWh,
                    spotPriceOre: effectiveSpotOre,
                    profile: costProfile,
                    hoursInPeriod: 730
                ).totalKr
            }

            return totalCostService.calculateTotalCost(
                kWh: consumption.totalKWh,
                spotPriceOre: averagePrice,
                profile: costProfile,
                hoursInPeriod: 730
            ).totalKr
        }
        return nil
    }

    private var liveCostForCurrentMonth: Double? {
        guard isCurrentMonth,
              let kWh = summary.totalConsumptionKWh,
              kWh > 0 else {
            return summary.totalCostSEK
        }

        let spotOre = summary.averageSpotPriceOrePerKWh ?? 0
        return totalCostService.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: spotOre,
            profile: costProfile,
            hoursInPeriod: 730
        ).totalKr
    }

    private func averagePriceMetric(
        _ summary: HistoricalEnergySummaryValue,
        liveCost: Double?
    ) -> (title: String, value: String, unit: String) {
        if let cost = liveCost, let kWh = summary.totalConsumptionKWh, kWh > 0 {
            let avg = cost / kWh
            return (
                "Snitt totalpris",
                avg.formatted(.number.precision(.fractionLength(2))),
                "kr/kWh"
            )
        }
        if let totalPrice = summary.averageTotalCostSEKPerKWh {
            return (
                "Snitt totalpris",
                totalPrice.formatted(.number.precision(.fractionLength(2))),
                "kr/kWh"
            )
        }
        if let spotPrice = summary.averageSpotPriceOrePerKWh {
            return (
                "Snitt spotpris",
                AppFormatters.oreValue(spotPrice),
                "öre"
            )
        }
        return ("Snittpris", "-", "kr/kWh")
    }
}
