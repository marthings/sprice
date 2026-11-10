import SwiftUI

struct CostExamplesSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let profile: CostProfile

    private let totalCostService = TotalCostService.shared

    private var currentPrice: Double {
        payload.day.currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(HouseholdCostExample.catalog) { example in
                    CostExampleCard(
                        example: example,
                        cost: totalCostService.calculateTotalCost(
                            kWh: example.kWh,
                            spotPriceOre: currentPrice,
                            profile: profile,
                            hoursInPeriod: example.hoursInPeriod
                        )
                    )
                }
            }

        }
    }

    private var header: some View {
        SectionInfoHeader(
            title: "Exempel med detta pris",
            paragraphs: infoParagraphs
        )
    }

    private var infoParagraphs: [String] {
        var parts = [
            "Korten visar ungefär vad vanliga saker kostar till det pris som gäller just nu.",
            HouseholdCostExample.catalogFootnote
        ]
        if let basisText = profile.retailContractCostBasisText {
            parts.append(basisText)
        }
        if profile.gridMonthlyFee != nil || profile.gridTransferOrePerKWh != nil {
            parts.append("Elnätskostnaden baseras på dina elnätsuppgifter och kan avvika från fakturan.")
        }
        return parts
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm)
        ]
    }

}

private struct CostExampleCard: View {
    let example: HouseholdCostExample
    let cost: EnhancedCost

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {


                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(example.title)
                        .font(DS.Font.semibold(13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(example.subtitle)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(cost.totalKr, format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.bold(20).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("kr")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                breakdownRow("Elhandel", cost.providerTotalKr)
                breakdownRow("Elnät", cost.gridTotalKr)
                breakdownRow("Skatt/avg.", cost.taxesAndFeesKr)
                breakdownRow("Moms", cost.vatKr)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .spriceCard(tone: .cost)
    }

    private func breakdownRow(_ title: String, _ value: Double) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.xs)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.micro.monospacedDigit())
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    let now = Date()
    let buckets = (0..<24).map { hour in
        PriceBucket(
            start: Calendar.current.date(byAdding: .hour, value: hour, to: Calendar.current.startOfDay(for: now)) ?? now,
            end: Calendar.current.date(byAdding: .hour, value: hour + 1, to: Calendar.current.startOfDay(for: now)) ?? now,
            orePerKWh: Double(40 + hour * 3),
            category: hour < 8 ? .low : hour < 18 ? .medium : .high
        )
    }
    let day = DayChartData(buckets: buckets, thresholds: Thresholds(lowUpper: 60, mediumUpper: 90), minOre: 40, maxOre: 109)
    CostExamplesSection(
        payload: .init(currentDisplay: "72", day: day),
        profile: .swedishDefaultEstimate()
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
