import SwiftUI

struct CostExamplesSection: View {
    let payload: SpotPriceViewModel.CurrentAndDay
    let profile: CostProfile

    private let totalCostService = TotalCostService()

    private var currentPrice: Double {
        payload.day.currentBucket?.orePerKWh ?? averagePrice(payload.day.buckets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(examples) { example in
                    CostExampleCard(
                        example: example,
                        cost: totalCostService.calculateTotalCost(
                            kWh: example.kWh,
                            spotPriceOre: currentPrice,
                            profile: profile,
                            hoursInPeriod: example.hoursInPeriod
                        ),
                        profile: profile
                    )
                }
            }

            if profile.gridMonthlyFee != nil || profile.gridTransferOrePerKWh != nil {
                Label("Elnätskostnaden baseras på dina elnätsuppgifter och kan avvika från fakturan.", systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .iosGlassCard(cornerRadius: DS.Radius.lg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kostnad med detta pris")
                    .font(DS.Font.headline)
                Spacer()
                Text(totalCostService.calculatePricePerKWh(spotPriceOre: currentPrice, profile: profile), format: .number.precision(.fractionLength(2)))
                    .font(DS.Font.semibold(13).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("kr/kWh")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            if let basisText = profile.retailContractCostBasisText {
                Label(basisText, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm)
        ]
    }

    private var examples: [CostExample] {
        [
            CostExample(
                title: "Dusch",
                subtitle: "10 min",
                kWh: 6.0,
                hoursInPeriod: 1.0,
                icon: "shower.fill",
                color: DS.Color.info
            ),
            CostExample(
                title: "Pizza i ugn",
                subtitle: "~1,1 kWh",
                kWh: 1.1,
                hoursInPeriod: 0.5,
                icon: "oven.fill",
                color: DS.Color.warning
            ),
            CostExample(
                title: "Värmepump",
                subtitle: "1 dygn",
                kWh: 24.0,
                hoursInPeriod: 24.0,
                icon: "heat.waves",
                color: DS.Color.danger
            ),
            CostExample(
                title: "Ladda bilen",
                subtitle: "~45 kWh",
                kWh: 45.0,
                hoursInPeriod: 8.0,
                icon: "ev.charger.fill",
                color: DS.Color.success
            )
        ]
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}

private struct CostExample: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let kWh: Double
    let hoursInPeriod: Double
    let icon: String
    let color: Color
}

private struct CostExampleCard: View {
    let example: CostExample
    let cost: EnhancedCost
    let profile: CostProfile

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
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                breakdownRow("Elhandel", cost.providerTotalKr)
                breakdownRow("Elnät", cost.gridTotalKr)
                breakdownRow("Skatt/avg.", cost.taxesAndFeesKr)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func breakdownRow(_ title: String, _ value: Double) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.xs)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.micro.monospacedDigit())
                .foregroundStyle(.secondary)
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
