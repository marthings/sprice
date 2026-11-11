import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SpotPriceViewModel()
    @State private var selectedSection = DashboardView.initialSection

    /// DEBUG only: `-StartTab 1` opens a given tab, so screenshots can be taken without tapping.
    private static var initialSection: Int {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-StartTab"),
           arguments.indices.contains(index + 1),
           let tab = Int(arguments[index + 1]) {
            return tab
        }
#endif
        return 0
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab("Kostnad", systemImage: "wallet.bifold.fill", value: 0) {
                CostTab(
                    state: viewModel.state,
                    monthlyConsumption: viewModel.monthlyConsumption,
                    preciseMonthlyCost: viewModel.preciseMonthlyCost,
                    measuredThrough: viewModel.consumptionMeasuredThrough,
                    powerPeaks: viewModel.powerPeaks,
                    notices: viewModel.costNotices,
                    onRetry: reload,
                    onRefresh: refresh
                )
            }

            Tab("Priser", systemImage: "chart.bar.fill", value: 1) {
                PriceTab(
                    state: viewModel.state,
                    costProfile: settingsCostProfile,
                    notices: viewModel.priceTabNotices,
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
                    notices: viewModel.consumptionNotice.map { [$0] } ?? [],
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
        .background { AppCanvasBackground(live: false) }
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
        let measuredThrough: Date?
        let powerPeaks: [PowerPeak]
        let notices: [FetchNotice]
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
                    measuredThrough: measuredThrough,
                    powerPeaks: powerPeaks,
                    notices: notices,
                    onRetry: onRetry
                )
            }
        }
    }
    
    private struct PriceTab: View {
        let state: SpotPriceViewModel.State
        let costProfile: CostProfile
        let notices: [FetchNotice]
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
                    notices: notices,
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
        let notices: [FetchNotice]
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
                    livePreciseCost: livePreciseCost,
                    notices: notices
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
            }
        }

        @State private var scrollPosition = ScrollPosition(edge: .top)

        @ViewBuilder
        private var tabBody: some View {
            if embedsInScrollView {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        tabContent()
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .scrollPosition($scrollPosition)
                .scrollContentBackground(.hidden)
                .spriceScrollContentMargins()
                .scrollDismissesKeyboard(.interactively)
#if DEBUG
                .task {
                    guard DebugLaunch.scrollY > 0 else { return }
                    try? await Task.sleep(for: .seconds(2))
                    scrollPosition.scrollTo(y: DebugLaunch.scrollY)
                }
#endif
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

#if DEBUG
/// DEBUG only launch arguments, so screenshots can be taken without tapping.
enum DebugLaunch {
    static func value(after flag: String) -> Double? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return Double(arguments[index + 1])
    }

    /// `-ScrollY 800` scrolls the first screen that reads it.
    static var scrollY: CGFloat { CGFloat(value(after: "-ScrollY") ?? 0) }
}
#endif
