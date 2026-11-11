import SwiftUI

struct DashboardHeader: View {
    let title: String
    let settingsSummary: String
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.fixed(titleSize))
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
                .tint(DS.Color.warning)
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
                .font(.system(size: DS.Size.iconXL, weight: .light))
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
