import SwiftUI

/// Every web address the app links to, in one place.
/// TODO: placeholders that point to GitHub until the real privacy policy page
/// and support address are decided. Change them here and nowhere else.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://github.com/marthings/sprice/blob/main/Docs/integritet.md")!
    static let support = URL(string: "https://github.com/marthings/sprice/issues")!
    /// Credit the price source asks for.
    static let priceSource = URL(string: "https://www.elprisetjustnu.se")!
    /// Credit the temperature source asks for.
    static let temperatureSource = URL(string: "https://open-meteo.com")!
}

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
                    .font(DS.Font.footnote)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spriceCard()
    }
}

struct SettingsSavedLabel: View {
    var body: some View {
        Label("Sparat", systemImage: "checkmark")
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.successText)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
