import SwiftUI

struct HistoryMonthView: View {
    let priceArea: String
    let costProfile: CostProfile
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?
    var notices: [FetchNotice] = []

    @State private var state: HistoryMonthLoadState = .loading
    @State private var selectedMonthKey: String?
    @State private var openedDay: HistoryDayRoute?
    @State private var openedInsights: ConsumptionInsightsRoute?
    @State private var temperatureInsights: [TemperatureInsight] = []
    @State private var temperatureNotice: FetchNotice?
    @State private var dailyTemperatures: [Date: Double] = [:]

    private let historyQuery: any EnergyHistoryQuerying
    private let initialState: HistoryMonthLoadState?
    private let previewInsights: ConsumptionInsights?
    private var hasProvider: Bool {
        !ConsumptionSettings.shared.selectedProviderId.isEmpty
    }

    init(
        priceArea: String,
        costProfile: CostProfile,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        previewState: HistoryMonthLoadState? = nil,
        previewInsights: ConsumptionInsights? = nil,
        liveMonthlyConsumption: ConsumptionData? = nil,
        livePreciseCost: PreciseMonthlyCost? = nil,
        notices: [FetchNotice] = []
    ) {
        self.priceArea = priceArea
        self.costProfile = costProfile
        self.historyQuery = historyQuery ?? EnergyHistoryQueryService()
        self.initialState = previewState
        self.previewInsights = previewInsights
        self.liveMonthlyConsumption = liveMonthlyConsumption
        self.livePreciseCost = livePreciseCost
        self.notices = notices
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            switch state {
            case .loading:
                DashboardLoadingView()
            case .empty(let message):
                AppStatusCard(
                    icon: "clock.badge",
                    title: "Ingen historik att visa",
                    message: message,
                    color: DS.Color.secondary
                )
            case .loaded(let presentation):
                HistoryMonthLoadedContent(
                    presentation: presentation,
                    hasProvider: hasProvider,
                    priceArea: priceArea,
                    costProfile: costProfile,
                    historyQuery: historyQuery,
                    previewInsights: previewInsights,
                    temperatureInsights: temperatureInsights,
                    dailyTemperatures: dailyTemperatures,
                    selectedMonthKey: $selectedMonthKey,
                    openedDay: $openedDay,
                    openedInsights: $openedInsights
                )
            }
            FetchNoticeStack(notices: notices + [temperatureNotice].compactMap { $0 })
        }
        .navigationDestination(item: $openedDay) { route in
            HistoryDayView(
                date: route.date,
                dayKey: route.dayKey,
                dailySummary: dailySummary(for: route),
                costProfile: costProfile,
                priceArea: priceArea,
                historyQuery: historyQuery
            )
        }
        .navigationDestination(item: $openedInsights) { route in
            ConsumptionInsightsScreen(
                route: route,
                costProfile: costProfile,
                dailySummaries: dailySummaries(for: route),
                historyQuery: historyQuery,
                previewInsights: previewInsights
            )
        }
        .task {
            if let initialState {
                state = initialState
            } else {
                await loadHistory()
                startBackfill()
            }
            await loadTemperature()
#if DEBUG
            // `-OpenDay 2` opens the day two days ago, for screenshots.
            if let daysAgo = DebugLaunch.value(after: "-OpenDay"), openedDay == nil,
               let date = Calendar.energyHistory.date(byAdding: .day, value: -Int(daysAgo), to: Date()) {
                openedDay = HistoryDayRoute(dayKey: EnergyHistoryKey.dayKey(for: date), date: date)
            }
#endif
        }
        .onChange(of: ConsumptionSettings.shared.temperaturePlaceId) { _, _ in
            Task { await loadTemperature() }
        }
        .onChange(of: selectedMonthKey) { oldValue, _ in
            guard initialState == nil else { return }
            guard oldValue != nil else { return }
            Task {
                await loadHistory()
                await loadTemperature()
            }
        }
        .onChange(of: livePreciseCost) { _, _ in
            applyLiveValuesIfNeeded()
        }
        .onChange(of: liveMonthlyConsumption) { _, _ in
            applyLiveValuesIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .energyHistoryDidUpdate)) { _ in
            guard initialState == nil else { return }
            ConsumptionInsightsService.invalidate()
            Task { await loadHistory() }
        }
    }

    private func startBackfill() {
        guard hasProvider else { return }
        let providerID = ConsumptionSettings.shared.selectedProviderId
        let costProfile = costProfile
        let priceArea = priceArea
        Task {
            await EnergyHistoryBackfillController.shared.runIfNeeded(
                consumptionService: ConsumptionService(),
                spotPriceService: SpotPriceService(),
                priceArea: priceArea,
                providerID: providerID,
                costProfile: costProfile
            )
        }
    }

    private func dailySummary(for route: HistoryDayRoute) -> HistoricalEnergySummaryValue? {
        guard case .loaded(let presentation) = state else { return nil }
        return presentation.dailySummaries.first { $0.periodKey == route.dayKey }
    }

    private func dailySummaries(for route: ConsumptionInsightsRoute) -> [HistoricalEnergySummaryValue] {
        guard case .loaded(let presentation) = state else { return [] }
        switch route.period {
        case .month:
            return presentation.dailySummaries
        case .day(let dayKey, _):
            return presentation.dailySummaries.filter { $0.periodKey == dayKey }
        }
    }

    private func applyLiveValuesIfNeeded() {
        guard initialState == nil else { return }
        guard case .loaded(let presentation) = state, presentation.isCurrentMonth else { return }
        state = .loaded(
            HistoryMonthPresentation.make(
                months: presentation.months,
                selectedMonth: presentation.selectedMonth,
                dailySummaries: presentation.dailySummaries,
                previousDailySummaries: presentation.previousDailySummaries,
                costProfile: costProfile,
                liveMonthlyConsumption: liveMonthlyConsumption,
                livePreciseCost: livePreciseCost
            )
        )
    }

    @MainActor
    private func loadHistory() async {
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            let now = Date()
            let calendar = Calendar.energyHistory
            let month = ConsumptionInsightsSampleData.previewMonthSummary(now: now, calendar: calendar)
            let previous = ConsumptionInsightsSampleData.previewPreviousMonthSummary(now: now, calendar: calendar)
            selectedMonthKey = month.periodKey
            state = .loaded(
                HistoryMonthPresentation.make(
                    months: [previous, month].compactMap { $0 },
                    selectedMonth: month,
                    dailySummaries: ConsumptionInsightsSampleData.previewDailySummaries(now: now, calendar: calendar),
                    previousDailySummaries: ConsumptionInsightsSampleData.previewPreviousDailySummaries(now: now, calendar: calendar),
                    costProfile: costProfile,
                    liveMonthlyConsumption: liveMonthlyConsumption,
                    livePreciseCost: livePreciseCost,
                    now: now,
                    calendar: calendar
                )
            )
            return
        }
#endif
        do {
            let history = try historyQuery.loadMonthHistory(
                priceArea: priceArea,
                selectedMonthKey: selectedMonthKey
            )

            if selectedMonthKey != history.selectedMonthKey {
                selectedMonthKey = history.selectedMonthKey
            }

            if history.months.isEmpty {
                state = .empty(HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider))
            } else {
                state = .loaded(
                    HistoryMonthPresentation.make(
                        months: history.months,
                        selectedMonth: history.selectedMonth,
                        dailySummaries: history.dailySummaries,
                        previousDailySummaries: history.previousDailySummaries,
                        costProfile: costProfile,
                        liveMonthlyConsumption: liveMonthlyConsumption,
                        livePreciseCost: livePreciseCost
                    )
                )
            }
        } catch {
            state = .empty(HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider))
        }
    }


    @MainActor
    private func loadTemperature() async {
#if DEBUG
        assert(TemperatureAdjustment.debugVerifyKnownExamples(), "temperature adjustment examples drifted")
#endif
        guard case .loaded(let presentation) = state,
              let selected = presentation.selectedMonth else {
            temperatureInsights = []
            dailyTemperatures = [:]
            temperatureNotice = nil
            return
        }

        let calendar = Calendar.energyHistory
        let now = Date()
        let place = ConsumptionSettings.shared.temperaturePlace
        let monthStart = calendar.dateInterval(of: .month, for: selected.periodStart)?.start ?? selected.periodStart
        let fetchStart = calendar.date(byAdding: .month, value: -24, to: monthStart) ?? monthStart
        let lastMeasured = SameDayMonthComparison.lastMeasuredDay(
            monthStart: monthStart,
            dailySummaries: presentation.dailySummaries
        ) ?? presentation.dayBars.last(where: { $0.costKr != nil })?.date ?? now

        let snapshot = await DailyTemperatureService.shared.temperatures(
            from: fetchStart,
            to: lastMeasured,
            place: place,
            now: now,
            calendar: calendar
        )
        dailyTemperatures = snapshot.days
        temperatureNotice = snapshot.notice

        var kWhByDay = TemperatureAdjustment.kWhByDay(from: presentation.dailySummaries, calendar: calendar)
        kWhByDay.merge(TemperatureAdjustment.kWhByDay(from: presentation.previousDailySummaries, calendar: calendar)) { current, _ in current }
        for month in presentation.months {
            let key = month.periodKey
            if key == presentation.selectedMonth?.periodKey { continue }
            if let extra = try? historyQuery.loadMonthHistory(priceArea: priceArea, selectedMonthKey: key) {
                kWhByDay.merge(TemperatureAdjustment.kWhByDay(from: extra.dailySummaries, calendar: calendar)) { current, _ in current }
            }
        }
#if DEBUG
        if ConsumptionInsightsSampleData.isLaunchPreviewEnabled {
            let skip = Set(kWhByDay.keys)
            kWhByDay.merge(
                ConsumptionInsightsSampleData.previewFitConsumption(
                    temperatures: snapshot.days,
                    skipping: skip,
                    calendar: calendar
                )
            ) { current, _ in current }
        }
#endif

        let baseloadKW = previewInsights?.baseload?.powerKW
        let fit = TemperatureAdjustment.fit(
            kWhByDay: kWhByDay,
            temperatures: snapshot.days,
            baseloadKW: baseloadKW,
            calendar: calendar
        )

        let previousStart = presentation.previousSnapshot?.summary.periodStart
            ?? presentation.months.filter { $0.periodStart < monthStart }.max(by: { $0.periodStart < $1.periodStart })?.periodStart
        let throughDay = previousStart.flatMap {
            SameDayMonthComparison.throughDay(
                currentMonthStart: monthStart,
                lastMeasuredInCurrent: lastMeasured,
                previousMonthStart: $0,
                now: now,
                calendar: calendar
            )
        }

        var insights: [TemperatureInsight] = []
        if let previousStart {
            let currentPeriod = TemperatureAdjustment.period(
                name: SameDayMonthComparison.swedishMonthName(monthStart),
                days: TemperatureAdjustment.daysInWindow(monthStart: monthStart, throughDay: throughDay, calendar: calendar),
                kWhByDay: kWhByDay,
                temperatures: snapshot.days,
                calendar: calendar
            )
            let referenceName = presentation.comparisonMonthName
                ?? SameDayMonthComparison.previousPeriodLabel(
                    from: TemperatureAdjustment.daysInWindow(monthStart: previousStart, throughDay: throughDay, calendar: calendar),
                    calendar: calendar
                )
                ?? SameDayMonthComparison.swedishMonthName(previousStart)
            let referencePeriod = TemperatureAdjustment.period(
                name: referenceName,
                days: TemperatureAdjustment.daysInWindow(monthStart: previousStart, throughDay: throughDay, calendar: calendar),
                kWhByDay: kWhByDay,
                temperatures: snapshot.days,
                calendar: calendar
            )
            if let currentPeriod, let referencePeriod,
               let insight = TemperatureAdjustment.insight(
                current: currentPeriod,
                reference: referencePeriod,
                fit: fit,
                id: "previous-month"
               ) {
                insights.append(insight)
            }
        }

        if let yearAgo = calendar.date(byAdding: .year, value: -1, to: monthStart),
           presentation.months.contains(where: { calendar.isDate($0.periodStart, equalTo: yearAgo, toGranularity: .month) }) {
            let yearThrough = calendar.isDate(monthStart, equalTo: now, toGranularity: .month)
                ? (throughDay ?? calendar.component(.day, from: lastMeasured))
                : nil
            let currentPeriod = TemperatureAdjustment.period(
                name: SameDayMonthComparison.swedishMonthName(monthStart),
                days: TemperatureAdjustment.daysInWindow(monthStart: monthStart, throughDay: yearThrough, calendar: calendar),
                kWhByDay: kWhByDay,
                temperatures: snapshot.days,
                calendar: calendar
            )
            let yearName = "\(SameDayMonthComparison.swedishMonthName(yearAgo)) förra året"
            let referencePeriod = TemperatureAdjustment.period(
                name: yearName,
                days: TemperatureAdjustment.daysInWindow(monthStart: yearAgo, throughDay: yearThrough, calendar: calendar),
                kWhByDay: kWhByDay,
                temperatures: snapshot.days,
                calendar: calendar
            )
            if let currentPeriod, let referencePeriod,
               let insight = TemperatureAdjustment.insight(
                current: currentPeriod,
                reference: referencePeriod,
                fit: fit,
                id: "previous-year"
               ) {
                insights.append(insight)
            }
        }

        temperatureInsights = insights
    }
}
