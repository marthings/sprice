import SwiftUI

struct DashboardView: View {
    @State private var viewModel = SpotPriceViewModel()
    @State private var isShowingSettings = false
    @State private var selectedSection = 0
    @State private var selectedChartDate: Date?

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab("Kostnad", systemImage: "wallet.bifold.fill", value: 0) {
                CostTab(
                    state: viewModel.state,
                    settingsSummary: settingsSummary,
                    monthlyConsumption: viewModel.monthlyConsumption,
                    preciseMonthlyCost: viewModel.preciseMonthlyCost,
                    isShowingSettings: $isShowingSettings,
                    onRetry: reload
                )
            }

            Tab("Priser", systemImage: "chart.bar.fill", value: 1) {
                PriceTab(
                    state: viewModel.state,
                    settingsSummary: settingsSummary,
                    costProfile: settingsSummaryCostProfile,
                    selectedChartDate: $selectedChartDate,
                    isShowingSettings: $isShowingSettings,
                    onRetry: reload
                )
            }

            Tab("Historik", systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryTab(
                    settingsSummary: settingsSummary,
                    priceArea: settingsSummaryPriceArea,
                    costProfile: settingsSummaryCostProfile,
                    isShowingSettings: $isShowingSettings,
                    liveMonthlyConsumption: viewModel.monthlyConsumption,
                    livePreciseCost: viewModel.preciseMonthlyCost
                )
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingSettings) {
            AppSettingsView()
        }
    }
    
    // MARK: - Tab Views
    
    private struct CostTab: View {
        let state: SpotPriceViewModel.State
        let settingsSummary: String
        let monthlyConsumption: ConsumptionData?
        let preciseMonthlyCost: PreciseMonthlyCost?
        @Binding var isShowingSettings: Bool
        let onRetry: () -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Kostnad",
                settingsSummary: settingsSummary,
                isShowingSettings: $isShowingSettings
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
        @Binding var selectedChartDate: Date?
        @Binding var isShowingSettings: Bool
        let onRetry: () -> Void
        
        var body: some View {
            DashboardTabShell(
                title: "Priser",
                settingsSummary: settingsSummary,
                isShowingSettings: $isShowingSettings
            ) {
                DailyPriceTabView(
                    state: state,
                    costProfile: costProfile,
                    selectedChartDate: $selectedChartDate,
                    onRetry: onRetry
                )
            }
        }
    }
    
    private struct HistoryTab: View {
        let settingsSummary: String
        let priceArea: String
        let costProfile: CostProfile
        @Binding var isShowingSettings: Bool

        // Live current-month data so Historik can show *exactly* the same headline numbers
        // (Kostnad + Förbrukning) as the Förbrukning tab for the open month.
        let liveMonthlyConsumption: ConsumptionData?
        let livePreciseCost: PreciseMonthlyCost?

        var body: some View {
            DashboardTabShell(
                title: "Historik",
                settingsSummary: settingsSummary,
                isShowingSettings: $isShowingSettings
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
        @Binding var isShowingSettings: Bool
        @ViewBuilder let tabContent: () -> TabContent

        var body: some View {
            NavigationStack {
                ZStack {
                    Image("bg")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

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
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                        .accessibilityLabel("Inställningar")
                    }
                }
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
}

#Preview {
    DashboardView()
}
