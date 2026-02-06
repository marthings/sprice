//
//  ProviderCredentialsSection.swift
//  Spotprice
//
//  Dynamic credential fields section for provider settings
//

import SwiftUI

struct ProviderCredentialsSection: View {
    @ObservedObject var settings: ConsumptionSettings
    let providerId: String

    private var metadata: ProviderMetadata? {
        ProviderRegistry.shared.metadata(for: providerId)
    }

    var body: some View {
        if let metadata = metadata {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Header with provider name
                Text("Koppla till \(metadata.displayName)")
                    .font(DS.Font.title)
                    .foregroundStyle(.primary)

                // Credential fields
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(metadata.credentialFields) { field in
                        CredentialFieldView(
                            field: field,
                            value: bindingForField(field.id)
                        )
                    }
                }

                // Help section (if available)
                if let helpText = metadata.credentialHelpText {
                    ProviderHelpSection(
                        helpText: helpText,
                        portalURL: metadata.portalURL
                    )
                }
            }
        }
    }

    private func bindingForField(_ fieldId: String) -> Binding<String> {
        Binding(
            get: {
                settings.getCredentials(for: providerId)[fieldId]
            },
            set: { newValue in
                var creds = settings.getCredentials(for: providerId)
                creds[fieldId] = newValue
                settings.setCredentials(creds, for: providerId)
            }
        )
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
            Label("Hitta dina uppgifter", systemImage: "questionmark.circle")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)

            Text(helpText)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)

            if let url = portalURL {
                Link(destination: url) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Öppna kundportal")
                            .font(DS.Font.medium(11))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: DS.Radius.md))
    }
}

#Preview {
    ProviderCredentialsSection(
        settings: ConsumptionSettings.shared,
        providerId: "vaggeryd"
    )
    .padding()
}
