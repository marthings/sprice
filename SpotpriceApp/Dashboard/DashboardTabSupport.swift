import SwiftUI

struct DashboardHeader: View {
    let title: String
    let settingsSummary: String
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.fixed(titleSize))
                .tracking(DS.Font.headingTracking(forSize: titleSize))
                .foregroundStyle(.primary)

            Text(settingsSummary)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(2)
        }
    }
}

struct DashboardLoadingView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(DS.Color.accent)
            Text("Hämtar elpriser")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}

struct DashboardErrorView: View {
    let notice: FetchNotice
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: notice.icon)
                .font(.system(size: DS.Size.iconXL, weight: .semibold))
                .foregroundStyle(DS.Color.danger)
                .accessibilityHidden(true)
            Text(notice.title)
                .font(DS.Font.headline)
                .multilineTextAlignment(.center)
            if let detail = notice.detail, !detail.isEmpty {
                Text(detail)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                onRetry()
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color.black)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 360)
        .spriceCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.accessibilityText)
    }
}

/// Small, calm label in the toolbar (it gets the system's own pill there) at the top of every tab while example data is shown, so that
/// nobody mistakes it for a real household.
struct DemoModeBadge: View {
    var body: some View {
        Text("Exempeldata")
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.accentText)
            .accessibilityLabel("Du ser exempeldata, inte din egen")
    }
}

/// Offered where an empty tab says that a data source is missing.
struct DemoModeButton: View {
    var body: some View {
        Button {
            ConsumptionSettings.shared.setDemoMode(true)
        } label: {
            Label("Prova med exempeldata", systemImage: "sparkles")
        }
        .buttonStyle(.bordered)
        .tint(DS.Color.accentText)
        .accessibilityHint("Visar påhittad data så att du kan prova appen utan konto")
    }
}
