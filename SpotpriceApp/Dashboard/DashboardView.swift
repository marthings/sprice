import SwiftUI

struct DashboardView: View {
    @State private var viewModel = SpotPriceViewModel()
    @State private var isShowingSettings = false
    @State private var selectedSection = 0
    @State private var selectedChartDate: Date?

    var body: some View {
        TabView(selection: $selectedSection) {
            // Tab 1: Kostnad
            CostTab(
                state: viewModel.state,
                settingsSummary: settingsSummary,
                monthlyConsumption: viewModel.monthlyConsumption,
                preciseMonthlyCost: viewModel.preciseMonthlyCost,
                isShowingSettings: $isShowingSettings,
                onRetry: reload
            )
            .tabItem {
                Label("Kostnad", systemImage: "wallet.bifold.fill")
            }
            .tag(0)
            
            // Tab 2: Priser
            PriceTab(
                state: viewModel.state,
                settingsSummary: settingsSummary,
                selectedChartDate: $selectedChartDate,
                isShowingSettings: $isShowingSettings,
                onRetry: reload
            )
            .tabItem {
                Label("Priser", systemImage: "chart.bar.fill")
            }
            .tag(1)
            
            // Tab 3: Förbrukning
            ConsumptionTab(
                state: viewModel.state,
                settingsSummary: settingsSummary,
                monthlyConsumption: viewModel.monthlyConsumption,
                powerPeaks: viewModel.powerPeaks,
                consumptionError: viewModel.consumptionError,
                preciseMonthlyCost: viewModel.preciseMonthlyCost,
                historySummary: viewModel.currentMonthHistorySummary,
                isShowingSettings: $isShowingSettings,
                onRetry: reload
            )
            .tabItem {
                Label("Förbrukning", systemImage: "bolt.fill")
            }
            .tag(2)

            HistoryTab(
                settingsSummary: settingsSummary,
                isShowingSettings: $isShowingSettings,
                liveMonthlyConsumption: viewModel.monthlyConsumption,
                livePreciseCost: viewModel.preciseMonthlyCost
            )
            .tabItem {
                Label("Historik", systemImage: "clock.arrow.circlepath")
            }
            .tag(3)
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingSettings) {
            AppSettingsView()
        }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
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
            NavigationStack {
                ContentView(title: "Kostnad", settingsSummary: settingsSummary) {
                    CostTabView(
                        state: state,
                        monthlyConsumption: monthlyConsumption,
                        preciseMonthlyCost: preciseMonthlyCost,
                        onRetry: onRetry
                    )
                }
                .toolbarBackground(.hidden, for: .navigationBar)
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
    
    private struct PriceTab: View {
        let state: SpotPriceViewModel.State
        let settingsSummary: String
        @Binding var selectedChartDate: Date?
        @Binding var isShowingSettings: Bool
        let onRetry: () -> Void
        
        var body: some View {
            NavigationStack {
                ContentView(title: "Priser", settingsSummary: settingsSummary) {
                    DailyPriceTabView(
                        state: state,
                        selectedChartDate: $selectedChartDate,
                        onRetry: onRetry
                    )
                }
                .toolbarBackground(.hidden, for: .navigationBar)
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
    
    private struct ConsumptionTab: View {
        let state: SpotPriceViewModel.State
        let settingsSummary: String
        let monthlyConsumption: ConsumptionData?
        let powerPeaks: [PowerPeak]
        let consumptionError: String?
        let preciseMonthlyCost: PreciseMonthlyCost?
        let historySummary: HistoricalEnergySummaryValue?
        @Binding var isShowingSettings: Bool
        let onRetry: () -> Void
        
        var body: some View {
            NavigationStack {
                ContentView(title: "Förbrukning", settingsSummary: settingsSummary) {
                    ConsumptionTabView(
                        state: state,
                        monthlyConsumption: monthlyConsumption,
                        powerPeaks: powerPeaks,
                        consumptionError: consumptionError,
                        preciseMonthlyCost: preciseMonthlyCost,
                        historySummary: historySummary,
                        onConfigureConsumption: { isShowingSettings = true },
                        onRetry: onRetry
                    )
                }
                .toolbarBackground(.hidden, for: .navigationBar)
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

    private struct HistoryTab: View {
        let settingsSummary: String
        @Binding var isShowingSettings: Bool

        // Live current-month data so Historik can show *exactly* the same headline numbers
        // (Kostnad + Förbrukning) as the Förbrukning tab for the open month.
        let liveMonthlyConsumption: ConsumptionData?
        let livePreciseCost: PreciseMonthlyCost?

        var body: some View {
            NavigationStack {
                ContentView(title: "Historik", settingsSummary: settingsSummary) {
                    HistoryMonthView(
                        liveMonthlyConsumption: liveMonthlyConsumption,
                        livePreciseCost: livePreciseCost
                    )
                }
                .toolbarBackground(.hidden, for: .navigationBar)
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
    
    // MARK: - Content Wrapper
    
    // Enkel wrapper för varje tab
    private struct ContentView<Content: View>: View {
        let title: String
        let settingsSummary: String
        @ViewBuilder let content: Content
        
        var body: some View {
            ZStack {
                Image("bg")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        DashboardHeader(title: title, settingsSummary: settingsSummary)
                        content
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl * 4)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var settingsSummary: String {
        let profile = ConsumptionSettings.shared.costProfile
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
