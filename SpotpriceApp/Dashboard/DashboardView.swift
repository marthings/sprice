import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SpotPriceViewModel()
    @State private var selectedSection = 0

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab("Kostnad", systemImage: "wallet.bifold.fill", value: 0) {
                CostTab(
                    state: viewModel.state,
                    monthlyConsumption: viewModel.monthlyConsumption,
                    preciseMonthlyCost: viewModel.preciseMonthlyCost,
                    powerPeaks: viewModel.powerPeaks,
                    onRetry: reload,
                    onRefresh: refresh
                )
            }

            Tab("Priser", systemImage: "chart.bar.fill", value: 1) {
                PriceTab(
                    state: viewModel.state,
                    costProfile: settingsCostProfile,
                    onRetry: reload,
                    onRefresh: refresh
                )
            }

            Tab("Historik", systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryTab(
                    priceArea: settingsPriceArea,
                    costProfile: settingsCostProfile,
                    liveMonthlyConsumption: viewModel.monthlyConsumption,
                    livePreciseCost: viewModel.preciseMonthlyCost,
                    onRefresh: refresh
                )
            }

            Tab("Inställningar", systemImage: "gearshape", value: 3) {
                DashboardTabShell(
                    title: "Inställningar",
                    onRefresh: refresh,
                    showsRefresh: false,
                    embedsInScrollView: false
                ) {
                    AppSettingsView()
                }
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.handleForeground() }
        }
    }
    
    // MARK: - Tab Views
    
    private struct CostTab: View {
        let state: SpotPriceViewModel.State
        let monthlyConsumption: ConsumptionData?
        let preciseMonthlyCost: PreciseMonthlyCost?
        let powerPeaks: [PowerPeak]
        let onRetry: () -> Void
        let onRefresh: () async -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Kostnad",
                onRefresh: onRefresh
            ) {
                CostTabView(
                    state: state,
                    monthlyConsumption: monthlyConsumption,
                    preciseMonthlyCost: preciseMonthlyCost,
                    powerPeaks: powerPeaks,
                    onRetry: onRetry
                )
            }
        }
    }
    
    private struct PriceTab: View {
        let state: SpotPriceViewModel.State
        let costProfile: CostProfile
        let onRetry: () -> Void
        let onRefresh: () async -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Priser",
                onRefresh: onRefresh
            ) {
                DailyPriceTabView(
                    state: state,
                    costProfile: costProfile,
                    onRetry: onRetry
                )
            }
        }
    }
    
    private struct HistoryTab: View {
        let priceArea: String
        let costProfile: CostProfile

        // Live current-month data so Historik can show *exactly* the same headline numbers
        // (Kostnad + Förbrukning) as the Förbrukning tab for the open month.
        let liveMonthlyConsumption: ConsumptionData?
        let livePreciseCost: PreciseMonthlyCost?
        let onRefresh: () async -> Void

        var body: some View {
            DashboardTabShell(
                title: "Historik",
                onRefresh: onRefresh
            ) {
                HistoryMonthView(
                    priceArea: priceArea,
                    costProfile: costProfile,
                    liveMonthlyConsumption: liveMonthlyConsumption,
                    livePreciseCost: livePreciseCost
                )
            }
        }
    }

    private struct DashboardTabShell<TabContent: View>: View {
        let title: String
        let onRefresh: () async -> Void
        var showsRefresh: Bool = true
        var embedsInScrollView: Bool = true
        @ViewBuilder let tabContent: () -> TabContent

        var body: some View {
            NavigationStack {
                tabBody
                    .background { AppCanvasBackground() }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            }
        }

        @ViewBuilder
        private var tabBody: some View {
            if embedsInScrollView {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        tabContent()
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl * 4)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .modifier(DashboardRefreshModifier(isEnabled: showsRefresh, onRefresh: onRefresh))
            } else {
                tabContent()
            }
        }
    }

    private var settingsCostProfile: CostProfile {
        ConsumptionSettings.shared.costProfile
    }

    private var settingsPriceArea: String {
        settingsCostProfile.priceArea
    }

    private func reload() {
        Task { await viewModel.load() }
    }

    private func refresh() async {
        await viewModel.refreshFromUser()
    }
}

private struct DashboardRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let onRefresh: () async -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
    }
}

#Preview {
    DashboardView()
}
