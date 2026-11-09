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
                    settingsSummary: settingsSummary,
                    monthlyConsumption: viewModel.monthlyConsumption,
                    preciseMonthlyCost: viewModel.preciseMonthlyCost,
                    onRetry: reload,
                    onRefresh: refresh
                )
            }

            Tab("Priser", systemImage: "chart.bar.fill", value: 1) {
                PriceTab(
                    state: viewModel.state,
                    settingsSummary: settingsSummary,
                    costProfile: settingsSummaryCostProfile,
                    onRetry: reload,
                    onRefresh: refresh
                )
            }

            Tab("Historik", systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryTab(
                    settingsSummary: settingsSummary,
                    priceArea: settingsSummaryPriceArea,
                    costProfile: settingsSummaryCostProfile,
                    liveMonthlyConsumption: viewModel.monthlyConsumption,
                    livePreciseCost: viewModel.preciseMonthlyCost,
                    onRefresh: refresh
                )
            }

            Tab("Inställningar", systemImage: "gearshape", value: 3) {
                AppSettingsView()
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
        let settingsSummary: String
        let monthlyConsumption: ConsumptionData?
        let preciseMonthlyCost: PreciseMonthlyCost?
        let onRetry: () -> Void
        let onRefresh: () async -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Kostnad",
                settingsSummary: settingsSummary,
                onRefresh: onRefresh
            ) {
                CostTabView(
                    state: state,
                    monthlyConsumption: monthlyConsumption,
                    preciseMonthlyCost: preciseMonthlyCost,
                    onRetry: onRetry
                )
            }
        }
    }
    
    private struct PriceTab: View {
        let state: SpotPriceViewModel.State
        let settingsSummary: String
        let costProfile: CostProfile
        let onRetry: () -> Void
        let onRefresh: () async -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Priser",
                settingsSummary: settingsSummary,
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
        let settingsSummary: String
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
                settingsSummary: settingsSummary,
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
        let settingsSummary: String
        let onRefresh: () async -> Void
        @ViewBuilder let tabContent: () -> TabContent

        var body: some View {
            NavigationStack {
                ZStack {
                    AppCanvasBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                            DashboardHeader(title: title, settingsSummary: settingsSummary)
                            tabContent()
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.xl * 4)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await onRefresh()
                    }
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            }
        }
    }

    private var settingsSummaryCostProfile: CostProfile {
        ConsumptionSettings.shared.costProfile
    }

    private var settingsSummaryPriceArea: String {
        settingsSummaryCostProfile.priceArea
    }

    private var settingsSummary: String {
        let profile = settingsSummaryCostProfile
        var parts = [profile.priceArea, profile.retailContractDisplayName]

        if let gridCompanyName = profile.gridCompanyName, !gridCompanyName.isEmpty {
            parts.append(gridCompanyName)
        }

        return parts.joined(separator: " ")
    }

    private func reload() {
        Task { await viewModel.load() }
    }

    private func refresh() async {
        await viewModel.refreshFromUser()
    }
}

#Preview {
    DashboardView()
}
