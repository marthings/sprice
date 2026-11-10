import SwiftUI

struct HistoryMonthChrome: View {
    let months: [HistoricalEnergySummaryValue]
    let selectedMonth: HistoricalEnergySummaryValue?
    let comparisonMonthName: String?
    @Binding var selectedMonthKey: String?

    private var selectedIndex: Int? {
        guard let selectedMonth else { return nil }
        return months.firstIndex { $0.periodKey == selectedMonth.periodKey }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.md) {
                monthButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Föregående månad",
                    isEnabled: canGoOlder
                ) {
                    goOlder()
                }

                Spacer(minLength: 0)

                VStack(spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(monthTitle)
                            .font(DS.Font.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        if selectedMonth.map({ HistoryMonthFormatting.isCurrentMonth($0) }) == true {
                            Text("Pågår")
                                .font(DS.Font.footnote)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Color.warning.opacity(0.18), in: Capsule())
                                .accessibilityLabel("Månaden pågår")
                        }
                    }

                    if let comparisonMonthName {
                        Text("Jämförd med \(comparisonMonthName)")
                            .font(DS.Font.footnote)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }

                Spacer(minLength: 0)

                monthButton(
                    systemImage: "chevron.right",
                    accessibilityLabel: "Nästa månad",
                    isEnabled: canGoNewer
                ) {
                    goNewer()
                }
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity)
        .spriceCard(tone: .history)
        .accessibilityElement(children: .contain)
    }

    private var monthTitle: String {
        guard let selectedMonth else { return "Välj månad" }
        return AppFormatters.historyMonthLabel(selectedMonth.periodStart)
    }

    private var canGoOlder: Bool {
        guard let selectedIndex else { return false }
        return selectedIndex + 1 < months.count
    }

    private var canGoNewer: Bool {
        guard let selectedIndex else { return false }
        return selectedIndex > 0
    }

    private func goOlder() {
        guard let selectedIndex, selectedIndex + 1 < months.count else { return }
        selectedMonthKey = months[selectedIndex + 1].periodKey
    }

    private func goNewer() {
        guard let selectedIndex, selectedIndex > 0 else { return }
        selectedMonthKey = months[selectedIndex - 1].periodKey
    }

    private func monthButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.primary : DS.Color.secondary.opacity(0.4))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
