import SwiftUI

struct DashboardHeader: View {
    let title: String
    let settingsSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.bold(40))
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
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: DS.Size.iconXL, weight: .light))
                .foregroundStyle(DS.Color.secondary)
            Text("Kunde inte hämta priser")
                .font(DS.Font.headline)
            Text(message)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
            Button {
                onRetry()
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 360)
        .spriceCard()
    }
}
