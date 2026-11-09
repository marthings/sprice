import SwiftUI

struct ConsumptionInsightsMonthSection: View {
    let presentation: HistoryMonthPresentation
    let priceArea: String
    let costProfile: CostProfile
    let historyQuery: (any EnergyHistoryQuerying)?
    @Binding var openedInsights: ConsumptionInsightsRoute?
    var previewInsights: ConsumptionInsights? = nil

    @State private var insights: ConsumptionInsights?
    @State private var isLoading = false

    private var includeHypotheticalEffectTariff: Bool {
        ConsumptionSettings.shared.includeHypotheticalEffectTariff
    }

    var body: some View {
        ConsumptionInsightsTeaserCard(
            insights: insights,
            isLoading: isLoading,
            onOpen: open
        )
        .task(id: "\(route?.id ?? "")-\(includeHypotheticalEffectTariff)") {
            await load()
        }
    }

    private var route: ConsumptionInsightsRoute? {
        guard let selected = presentation.selectedMonth else { return nil }
        let previous = HistoryInsights.previousMonth(of: selected, in: presentation.months)
        return ConsumptionInsightsRoute(
            period: .month(
                monthKey: selected.periodKey,
                previousMonthKey: previous?.periodKey,
                periodStart: selected.periodStart
            ),
            priceArea: priceArea
        )
    }

    private func open() {
        openedInsights = route
    }

    @MainActor
    private func load() async {
        if let previewInsights {
            insights = previewInsights
            isLoading = false
            return
        }
        guard let route else {
            insights = nil
            isLoading = false
            return
        }
        isLoading = insights == nil
        insights = await ConsumptionInsightsService.insights(
            for: route,
            costProfile: costProfile,
            dailySummaries: presentation.dailySummaries,
            historyQuery: historyQuery
        )
        isLoading = false
    }
}

struct ConsumptionInsightsTeaserCard: View {
    let insights: ConsumptionInsights?
    let isLoading: Bool
    let onOpen: () -> Void

    var body: some View {
        if canOpen {
            Button(action: onOpen) {
                card
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Vad drog?")
            .accessibilityValue(teaserLine)
            .accessibilityHint("Öppnar mer om grundlast, toppar och tid på dygnet")
        } else {
            card
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vad drog?")
                .accessibilityValue(teaserLine)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Vad drog?")
                    .font(DS.Font.headline)
                    .foregroundStyle(.primary)
                Text(teaserLine)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if canOpen {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Visa mer")
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var canOpen: Bool {
        if isLoading { return true }
        guard let insights else { return false }
        return insights.resolution != .none
    }

    private var teaserLine: String {
        if isLoading && insights == nil {
            return "Räknar ut vad som drog."
        }
        if insights == nil || insights?.resolution == .none {
            return "Förbrukning saknas, så det går inte att räkna ut än."
        }
        return "Grundlast, toppar och när på dygnet det drog."
    }
}

struct ConsumptionInsightsDayTeaser: View {
    let insights: ConsumptionInsights?
    let onOpen: () -> Void

    var body: some View {
        ConsumptionInsightsTeaserCard(
            insights: insights,
            isLoading: insights == nil,
            onOpen: onOpen
        )
    }
}
