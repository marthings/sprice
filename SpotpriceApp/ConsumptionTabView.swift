import SwiftUI

struct ConsumptionTabView: View {
    let state: SpotPriceViewModel.State
    let monthlyConsumption: ConsumptionData?
    let powerPeaks: [PowerPeak]
    let consumptionError: String?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let onConfigureConsumption: () -> Void
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            DashboardLoadingView()
        case .failed(let message):
            DashboardErrorView(message: message, onRetry: onRetry)
        case .loaded(let payload):
            MonthlyConsumptionSection(
                consumption: monthlyConsumption,
                powerPeaks: powerPeaks,
                consumptionError: consumptionError,
                isConfigured: ConsumptionSettings.shared.isConfigured,
                averagePrice: averagePrice(payload.day.buckets),
                preciseCost: preciseMonthlyCost,
                profile: ConsumptionSettings.shared.costProfile,
                onConfigureConsumption: onConfigureConsumption
            )
        }
    }

    private func averagePrice(_ buckets: [PriceBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }
        return buckets.reduce(0) { $0 + $1.orePerKWh } / Double(buckets.count)
    }
}
