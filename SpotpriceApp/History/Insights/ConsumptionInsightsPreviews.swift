#if DEBUG
import SwiftUI

#Preview("Vad drog? månad") {
    previewStack {
        ConsumptionInsightsScreen(
            route: ConsumptionInsightsSampleData.octoberMonthRoute(),
            costProfile: .swedishDefaultEstimate(),
            dailySummaries: [],
            historyQuery: nil,
            previewInsights: ConsumptionInsightsSampleData.monthInsights()
        )
    }
}

#Preview("Vad drog? dag") {
    previewStack {
        ConsumptionInsightsScreen(
            route: ConsumptionInsightsSampleData.fridayRoute(),
            costProfile: .swedishDefaultEstimate(),
            dailySummaries: [],
            historyQuery: nil,
            previewInsights: ConsumptionInsightsSampleData.dayInsights()
        )
    }
}

#Preview("Vad drog? bara dygn") {
    previewStack {
        ConsumptionInsightsScreen(
            route: ConsumptionInsightsSampleData.octoberMonthRoute(),
            costProfile: .swedishDefaultEstimate(),
            dailySummaries: [],
            historyQuery: nil,
            previewInsights: ConsumptionInsightsSampleData.dailyOnlyInsights()
        )
    }
}

#Preview("Teaser") {
    previewStack {
        ConsumptionInsightsTeaserCard(
            insights: ConsumptionInsightsSampleData.monthInsights(),
            isLoading: false,
            onOpen: {}
        )
        .padding()
    }
}

private func previewStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    NavigationStack {
        content()
            .background(Color(.systemGroupedBackground))
    }
}
#endif
