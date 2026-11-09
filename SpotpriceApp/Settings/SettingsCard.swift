import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.headline)

            content

            if let footer {
                Text(footer)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard()
    }
}

struct SettingsSavedLabel: View {
    var body: some View {
        Label("Sparat", systemImage: "checkmark")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.success)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
