import SwiftUI

struct HistoryMonthView: View {
    let priceArea: String
    let costProfile: CostProfile
    let liveMonthlyConsumption: ConsumptionData?
    let livePreciseCost: PreciseMonthlyCost?

    @State private var state: HistoryMonthLoadState = .loading
    @State private var selectedMonthKey: String?
    @State private var viewMode: HistoryMonthViewMode = .chart
    @State private var selectedDay: HistoricalEnergySummaryValue?

    private let historyQuery: any EnergyHistoryQuerying
    private let initialState: HistoryMonthLoadState?

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
            case .failed(let message):
                AppStatusCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Kunde inte läsa historik",
                    message: message,
                    color: DS.Color.warning
                )
            case .loaded(let data):
                HistoryMonthLoadedContent(
                    data: data,
                    costProfile: costProfile,
                    liveMonthlyConsumption: liveMonthlyConsumption,
                    livePreciseCost: livePreciseCost,
                    selectedMonthKey: $selectedMonthKey,
                    viewMode: $viewMode,
                    selectedDay: $selectedDay
                )
            }
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

    @MainActor
    private func loadHistory() async {
        do {
            let history = try historyQuery.loadMonthHistory(
                priceArea: priceArea,
                selectedMonthKey: selectedMonthKey
            )

            // Only write back when the resolved key differs, so the initial
            // .task load doesn't trip .onChange into a redundant second fetch.
            if selectedMonthKey != history.selectedMonthKey {
                selectedMonthKey = history.selectedMonthKey
            }
            state = .loaded(HistoryMonthData(
                months: history.months,
                selectedMonth: history.selectedMonth,
                dailySummaries: history.dailySummaries,
                topCostDays: history.topCostDays,
                topConsumptionDays: history.topConsumptionDays
            ))
        } catch {
            state = .failed(error.userFacingMessage)
        }
    }
}