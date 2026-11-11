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

    private var includeElectricCarGuess: Bool {
        ConsumptionInsightsService.includeElectricCarGuess
    }

    var body: some View {
        ConsumptionInsightsTeaserCard(
            insights: insights,
            isLoading: isLoading,
            onOpen: open
        )
        .task(id: "\(route?.id ?? "")-\(includeHypotheticalEffectTariff)-\(includeElectricCarGuess)") {
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
        card
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.cardContent) {
            SectionInfoHeader(
                title: "Vad drog?",
                paragraphs: [
                    "Här ser du det du alltid drar, när topparna kom och när på dygnet det drog mest.",
                    "Öppna för mer om det du alltid drar, toppar och tid på dygnet."
                ]
            )

            if let evLine = insights?.evCharging?.shortSummary {
                Text(evLine)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(evLine + ". Det är en gissning, inte ett faktum.")
            }

            if isLoading && insights == nil {
                Text("Räknar ut vad som drog.")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
            } else if !canOpen {
                Text("Förbrukning saknas, så det går inte att räkna ut än.")
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if canOpen {
                Button(action: onOpen) {
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
                .buttonStyle(SpriceCardPressButtonStyle())
                .accessibilityLabel("Visa mer om vad som drog")
                .accessibilityHint("Öppnar det du alltid drar, toppar och tid på dygnet")
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard(tone: .history)
    }

    private var canOpen: Bool {
        if isLoading { return true }
        guard let insights else { return false }
        return insights.resolution != .none
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
