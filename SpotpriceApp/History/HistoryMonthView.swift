import SwiftUI

struct HistoryMonthView: View {
    let priceArea: String
    let costProfile: CostProfile
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?

    @State private var state: HistoryMonthLoadState = .loading
    @State private var selectedMonthKey: String?
    @State private var openedDay: HistoryDayRoute?

    private let historyQuery: any EnergyHistoryQuerying
    private let initialState: HistoryMonthLoadState?
    private var hasProvider: Bool {
        !ConsumptionSettings.shared.selectedProviderId.isEmpty
    }

    init(
        priceArea: String,
        costProfile: CostProfile,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        previewState: HistoryMonthLoadState? = nil,
        liveMonthlyConsumption: ConsumptionData? = nil,
        livePreciseCost: PreciseMonthlyCost? = nil
    ) {
        self.priceArea = priceArea
        self.costProfile = costProfile
        self.historyQuery = historyQuery ?? EnergyHistoryQueryService()
        self.initialState = previewState
        self.liveMonthlyConsumption = liveMonthlyConsumption
        self.livePreciseCost = livePreciseCost
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
            case .loaded(let data):
                HistoryMonthLoadedContent(
                    data: data,
                    costProfile: costProfile,
                    liveMonthlyConsumption: liveMonthlyConsumption,
                    livePreciseCost: livePreciseCost,
                    hasProvider: hasProvider,
                    selectedMonthKey: $selectedMonthKey,
                    openedDay: $openedDay
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
        .task {
            if let initialState {
                state = initialState
            } else {
                await loadHistory()
            }
        }
        .onChange(of: selectedMonthKey) { _, _ in
            guard initialState == nil else { return }
            Task { await loadHistory() }
        }
    }

    private func dailySummary(for route: HistoryDayRoute) -> HistoricalEnergySummaryValue? {
        guard case .loaded(let data) = state else { return nil }
        return data.dailySummaries.first { $0.periodKey == route.dayKey }
    }

    @MainActor
    private func loadHistory() async {
        do {
            let probe = try historyQuery.loadMonthHistory(
                priceArea: priceArea,
                selectedMonthKey: selectedMonthKey
            )
            let preferredKey = selectedMonthKey ?? HistoryInsights.preferredMonthKey(from: probe.months)
            let history: EnergyHistoryMonthQueryResult
            if preferredKey != probe.selectedMonthKey {
                history = try historyQuery.loadMonthHistory(
                    priceArea: priceArea,
                    selectedMonthKey: preferredKey
                )
            } else {
                history = probe
            }

            if selectedMonthKey != history.selectedMonthKey {
                selectedMonthKey = history.selectedMonthKey
            }

            if history.months.isEmpty {
                state = .empty(HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider))
            } else {
                state = .loaded(HistoryMonthData(
                    months: history.months,
                    selectedMonth: history.selectedMonth,
                    dailySummaries: history.dailySummaries
                ))
            }
        } catch {
            state = .empty(HistoryInsights.emptyHistoryMessage(hasProvider: hasProvider))
        }
    }
}
