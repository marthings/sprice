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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Vad drog?")
                .font(DS.Font.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .accessibilityLabel("Räknar ut vad som drog i perioden")
            } else if let insights {
                ForEach(Array(insights.summarySentences.enumerated()), id: \.offset) { _, sentence in
                    Text(sentence)
                        .font(DS.Font.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onOpen) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Visa Vad drog?")
                            .font(DS.Font.semibold(14))
                        Spacer(minLength: DS.Spacing.sm)
                        Image(systemName: "chevron.right")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öppnar en mer detaljerad bild av grundlast, toppar och tid på dygnet")
            } else {
                Text("Förbrukning saknas, så Vad drog? kan inte räknas ut än.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vad drog i perioden")
    }
}

struct ConsumptionInsightsDayTeaser: View {
    let insights: ConsumptionInsights?
    let route: ConsumptionInsightsRoute

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Vad drog?")
                        .font(DS.Font.headline)
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondary)
                }

                if let insights {
                    ForEach(Array(insights.summarySentences.prefix(2).enumerated()), id: \.offset) { _, sentence in
                        Text(sentence)
                            .font(DS.Font.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Räknar ut vad som drog den här dagen.")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spriceCard(tone: .history)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öppnar Vad drog för den här dagen")
    }
}
