//
//  ProviderCredentialsSection.swift
//  Spotprice
//
//  Dynamic credential fields section for provider settings
//

import SwiftUI

struct ProviderCredentialsSection: View {
    @Bindable var settings: ConsumptionSettings
    let providerId: String

    private var metadata: ProviderMetadata? {
        ProviderRegistry.shared.metadata(for: providerId)
    }

    var body: some View {
        if let metadata = metadata {
            Section {
                ForEach(metadata.credentialFields) { field in
                    CredentialFieldView(
                        field: field,
                        value: $settings[credential: field.id, provider: providerId]
                    )
                }
            } header: {
                Text("Koppla till \(metadata.displayName)")
            } footer: {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Detta är valfritt. Koppla en datakälla för månadstatistik, dygnsförbrukning och mer precisa insikter.")

                    if let helpText = metadata.credentialHelpText {
                        ProviderHelpSection(
                            helpText: helpText,
                            portalURL: metadata.portalURL
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Credential Field View

private struct CredentialFieldView: View {
    let field: CredentialField
    @Binding var value: String

    var body: some View {
        SettingsField(
            label: field.label,
            text: $value,
            hint: field.hint,
            isSecure: field.isSecure
        )
    }
}

// MARK: - Help Section

private struct ProviderHelpSection: View {
    let helpText: String
    let portalURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(helpText)

            if let url = portalURL {
                Link("Öppna kundportal", destination: url)
            }
        }
    }
}

#Preview {
    Form {
        ProviderCredentialsSection(
            settings: ConsumptionSettings.shared,
            providerId: "vaggeryd"
        )
    }
    .formStyle(.grouped)
    .frame(width: 420)
}