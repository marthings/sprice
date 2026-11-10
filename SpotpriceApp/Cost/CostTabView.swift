import SwiftUI

struct CostTabView: View {
    let state: SpotPriceViewModel.State
    let monthlyConsumption: ConsumptionData?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let measuredThrough: Date?
    let powerPeaks: [PowerPeak]
    let notices: [FetchNotice]
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let notice):
#if DEBUG
            if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
                previewInsightsContent(notices: [notice])
            } else {
                DashboardErrorView(notice: notice, onRetry: onRetry)
            }
#else
            DashboardErrorView(notice: notice, onRetry: onRetry)
#endif
        case .loaded(let payload):
            let settings = ConsumptionSettings.shared
            let profile = settings.costProfile
            let hypotheticalKr = TotalCostService.shared.hypotheticalMonthlyEffectTariffCostKr(
                peakKW: powerPeaks.first?.kW ?? 0,
                profile: profile,
                include: settings.includeHypotheticalEffectTariff
            )
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                FetchNoticeStack(notices: notices)
                CurrentCostHero(payload: payload)
                if settings.includeHypotheticalEffectTariff {
                    HypotheticalEffectTariffCard(
                        peak: powerPeaks.first,
                        amountKr: hypotheticalKr
                    )
                }
                CostUsageInsightsSection(
                    profile: profile,
                    priceArea: profile.priceArea,
                    measuredThrough: measuredThrough
                )
                MonthDailyCostSection(
                    priceArea: profile.priceArea,
                    profile: profile,
                    hasProvider: !settings.selectedProviderId.isEmpty,
                    hidesEmptyExplanation: notices.contains { $0.kind == .consumption },
                    forecastKr: CostTabForecast.monthTotal(
                        monthlyConsumption: monthlyConsumption,
                        preciseMonthlyCost: preciseMonthlyCost,
                        profile: profile,
                        measuredThrough: measuredThrough,
                        hypotheticalEffectTariffKr: hypotheticalKr
                    ),
                    measuredThrough: measuredThrough,
                    hypotheticalEffectTariffKr: hypotheticalKr
                )
                CostExamplesSection(payload: payload, profile: profile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

#if DEBUG
    @ViewBuilder
    private func previewInsightsContent(notices: [FetchNotice]) -> some View {
        let settings = ConsumptionSettings.shared
        let profile = settings.costProfile
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            FetchNoticeStack(notices: notices)
            CostUsageInsightsSection(
                profile: profile,
                priceArea: profile.priceArea,
                measuredThrough: measuredThrough
            )
            MonthDailyCostSection(
                priceArea: profile.priceArea,
                profile: profile,
                hasProvider: !settings.selectedProviderId.isEmpty,
                hidesEmptyExplanation: notices.contains { $0.kind == .consumption },
                forecastKr: nil,
                measuredThrough: measuredThrough,
                hypotheticalEffectTariffKr: nil
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
#endif
}

private enum CostTabForecast {
    static func monthTotal(
        monthlyConsumption: ConsumptionData?,
        preciseMonthlyCost: PreciseMonthlyCost?,
        profile: CostProfile,
        measuredThrough: Date?,
        hypotheticalEffectTariffKr: Double? = nil
    ) -> Double? {
        guard let monthlyConsumption else { return nil }
        guard let measuredThrough else { return nil }

        let spotPriceOre: Double
        if let preciseMonthlyCost, preciseMonthlyCost.totalKWh > 0 {
            spotPriceOre = (preciseMonthlyCost.totalCostKr / preciseMonthlyCost.totalKWh) * 100
        } else {
            return nil
        }

        guard let forecast = MonthlyCostEstimator().forecastMonthTotal(
            consumptionKWh: preciseMonthlyCost?.totalKWh ?? monthlyConsumption.totalKWh,
            spotPriceOre: spotPriceOre,
            profile: profile,
            measuredThrough: measuredThrough
        ) else {
            return nil
        }
        return forecast + (hypotheticalEffectTariffKr ?? 0)
    }
}

private struct HypotheticalEffectTariffCard: View {
    let peak: PowerPeak?
    let amountKr: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(EffectTariffCopy.lineTitle)
                .font(DS.Font.headline)
            if let amountKr {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                    Text(AppFormatters.wholeNumber(amountKr))
                        .font(DS.Font.bold(28).monospacedDigit())
                    Text("kr")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                if let peak {
                    Text("Räknat på \(powerPhrase(peak.kW)) \(AppFormatters.powerPeakHourLabel(peak.date)).")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let peak {
                Text("Högsta timmen är \(powerPhrase(peak.kW)). \(EffectTariffCopy.missingRate)")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ingen effekttopp att räkna på än. \(EffectTariffCopy.explanation)")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .cost)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let amountKr {
            return "\(EffectTariffCopy.lineTitle), \(AppFormatters.wholeNumber(amountKr)) kronor"
        }
        if let peak {
            return "Högsta timmen \(powerPhrase(peak.kW))"
        }
        return EffectTariffCopy.lineTitle
    }

    private func powerPhrase(_ kW: Double) -> String {
        if kW < 1 {
            return "\(Int((kW * 1000).rounded())) W"
        }
        return "\(kW.formatted(.number.precision(.fractionLength(1)))) kW"
    }
}

private struct CurrentCostHero: View {
    let payload: SpotPriceViewModel.CurrentAndDay

    private let totalCostService = TotalCostService.shared

    var body: some View {
        let profile = ConsumptionSettings.shared.costProfile
        let currentBucket = payload.day.currentBucket
        let spotPrice = currentBucket?.orePerKWh ?? PriceBucketAnalytics.averageSpotPrice(payload.day.buckets)
        let category = currentBucket?.category ?? DS.Color.categoryForPrice(spotPrice, min: payload.day.minOre, max: payload.day.maxOre)
        let nextTotal = nextTotalKrPerKWh(profile: profile)

        KilowattHourBreakdownView(
            breakdown: KilowattHourBreakdown.make(
                from: totalCostService.calculateTotalCost(
                    kWh: 1,
                    spotPriceOre: spotPrice,
                    profile: profile,
                    hoursInPeriod: 1
                ),
                profile: profile
            ),
            style: .regular,
            priceCategory: category,
            nextTotalKrPerKWh: nextTotal
        )
    }

    private func nextTotalKrPerKWh(profile: CostProfile) -> Double? {
        guard let currentBucket = payload.day.currentBucket,
              let nextBucket = payload.day.buckets.first(where: { $0.start >= currentBucket.end }) else {
            return nil
        }
        return totalCostService.calculatePricePerKWh(spotPriceOre: nextBucket.orePerKWh, profile: profile)
    }
}


private struct CostUsageInsightsSection: View {
    let profile: CostProfile
    let priceArea: String
    let measuredThrough: Date?

    @State private var fixedComparison: CostUsageInsights.FixedComparison?
    @State private var timing: CostUsageInsights.Timing?
    @State private var baseload: ConsumptionBaseloadInsight?
    @State private var dailySummaries: [HistoricalEnergySummaryValue] = []
    @State private var openedInsights: ConsumptionInsightsRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let fixedComparison {
                InsightRow(icon: "arrow.left.arrow.right", title: fixedComparison.title)
            }
            if let timing {
                InsightRow(icon: "clock", title: timing.title)
            }
            if let baseload {
                Button {
                    openedInsights = currentMonthRoute
                } label: {
                    InsightRow(
                        icon: "house",
                        title: baseloadTitle(baseload),
                        detail: "Visa Vad drog?",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öppnar Vad drog?")
            }
        }
        .navigationDestination(item: $openedInsights) { route in
            ConsumptionInsightsScreen(
                route: route,
                costProfile: profile,
                dailySummaries: dailySummaries,
                historyQuery: EnergyHistoryQueryService()
            )
        }
        .task(id: "\(priceArea)-\(measuredThrough?.timeIntervalSince1970 ?? 0)-\(ConsumptionSettings.shared.compareFixedPriceOrePerKWh)") {
            await load()
        }
    }

    private var currentMonthRoute: ConsumptionInsightsRoute {
        let start = measuredThrough ?? Date()
        let monthKey = EnergyHistoryKey.monthKey(for: start)
        return ConsumptionInsightsRoute(
            period: .month(
                monthKey: monthKey,
                previousMonthKey: nil,
                periodStart: Calendar.energyHistory.dateInterval(of: .month, for: start)?.start ?? start
            ),
            priceArea: priceArea
        )
    }

    private func baseloadTitle(_ baseload: ConsumptionBaseloadInsight) -> String {
        let power = ConsumptionInsightsBuilder.powerPhrase(baseload.powerKW)
        let kronor = AppFormatters.wholeNumber(baseload.costKr)
        return "Huset drar alltid ungefär \(power), det blir cirka \(kronor) kr den här månaden."
    }

    @MainActor
    private func load() async {
        var intervals: [HistoricalEnergyIntervalValue] = []
        var summaries: [HistoricalEnergySummaryValue] = []
        let now = Date()
        let calendar = Calendar.energyHistory
        let monthKey = EnergyHistoryKey.monthKey(for: measuredThrough ?? now)

#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            intervals = ConsumptionInsightsSampleData.previewIntervals(now: now, calendar: calendar)
            summaries = []
            apply(intervals: intervals, dailySummaries: summaries, now: now)
            return
        }
#endif

        do {
            let query = EnergyHistoryQueryService()
            intervals = try query.loadPreferredIntervals(monthKey: monthKey, priceArea: priceArea)
            summaries = try query.loadMonthHistory(priceArea: priceArea, selectedMonthKey: monthKey).dailySummaries
        } catch {
            intervals = []
            summaries = []
        }
        apply(intervals: intervals, dailySummaries: summaries, now: now)
    }

    @MainActor
    private func apply(
        intervals: [HistoricalEnergyIntervalValue],
        dailySummaries: [HistoricalEnergySummaryValue],
        now: Date
    ) {
        self.dailySummaries = dailySummaries
        let fixedOre = ConsumptionSettings.shared.compareFixedPriceOrePerKWh
        fixedComparison = CostUsageInsights.fixedComparison(
            intervals: intervals,
            profile: profile,
            fixedOrePerKWh: fixedOre > 0 ? fixedOre : CostUsageInsights.defaultFixedPriceOrePerKWh
        )
        timing = CostUsageInsights.timing(intervals: intervals, profile: profile)

        let monthStart = Calendar.energyHistory.dateInterval(of: .month, for: measuredThrough ?? now)?.start ?? now
        let monthEnd = Calendar.energyHistory.dateInterval(of: .month, for: monthStart)?.end ?? now
        let insights = ConsumptionInsightsBuilder.make(
            intervals: intervals,
            previousIntervals: [],
            dailySummaries: dailySummaries,
            costProfile: profile,
            periodStart: monthStart,
            periodEnd: monthEnd,
            now: now,
            periodKind: .month
        )
        baseload = insights.baseload
    }
}
