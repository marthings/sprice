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
            FetchNoticeStack(notices: notices)
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
                    selectedMonthKey: $selectedMonthKey,
                    openedDay: $openedDay,
                    openedInsights: $openedInsights
                )
            }
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
        }
        .onChange(of: selectedMonthKey) { oldValue, _ in
            guard initialState == nil else { return }
            guard oldValue != nil else { return }
            Task { await loadHistory() }
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
            selectedMonthKey = month.periodKey
            state = .loaded(
                HistoryMonthPresentation.make(
                    months: [month],
                    selectedMonth: month,
                    dailySummaries: ConsumptionInsightsSampleData.previewDailySummaries(now: now, calendar: calendar),
                    previousDailySummaries: [],
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
}
