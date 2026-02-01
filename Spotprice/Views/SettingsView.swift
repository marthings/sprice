//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = ConsumptionSettings.shared
    @State private var showSavedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header
            Text("Koppla till Vaggeryds Energi")
                .font(DS.Font.title)
                .foregroundStyle(.primary)

            // Inloggning
            VStack(alignment: .leading, spacing: DS.Spacing.md) {

                SettingsField(
                    label: "Kundnummer",
                    text: $settings.customerId,
                    hint: "Finns på din faktura"
                )

                SettingsField(
                    label: "Lösenord",
                    text: $settings.password,
                    hint: "De fyra sista siffrorna i ditt personnummer",
                    isSecure: true
                )
            }

            // Anläggning
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SettingsField(
                    label: "Konto-ID",
                    text: $settings.accountId,
                    hint: "Format: XXXXXXXXX-X (t.ex. 354404037-3)"
                )

                SettingsField(
                    label: "Anläggnings-ID",
                    text: $settings.utilityId,
                    hint: "18-siffrigt ID (t.ex. 735999252003205654)"
                )
            }

            // Hjälpsektion
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Hitta Konto-ID och Anläggnings-ID", systemImage: "questionmark.circle")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(.primary)

                Text("1. Öppna Mina Sidor i Chrome\n2. Logga in och gå till Förbrukning\n3. Öppna DevTools (Cmd+Option+I)\n4. Gå till Network-fliken\n5. Ladda om sidan och klicka på en \"1\"-request\n6. Under Headers → :path hittar du:")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(".../monthly/[Konto-ID]/[Anläggnings-ID]/...")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(DS.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary)
                    .cornerRadius(DS.Radius.sm)

                Link(destination: URL(string: "https://minasidor.vaggerydsenergi.se")!) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Öppna Mina Sidor")
                            .font(DS.Font.medium(11))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(DS.Spacing.md)
            .background(.quaternary.opacity(0.5))
            .cornerRadius(DS.Radius.md)

            Spacer()

            // Footer
            HStack {
                Button {
                    settings.reset()
                } label: {
                    Text("Återställ")
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.danger)
                        .cornerRadius(DS.Radius.md)
                        .font(DS.Font.medium(12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                if showSavedFeedback {
                    Label("Sparad!", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.success)
                        .transition(.opacity)
                } else if settings.isConfigured {
                    Label("Konfigurerad", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.success)
                } else {
                    Label("Ej konfigurerad", systemImage: "exclamationmark.circle.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.warning)
                }

                Button {
                    NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                    withAnimation {
                        showSavedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showSavedFeedback = false
                        }
                    }
                } label: {
                    Text("Spara")
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.primary)
                        .cornerRadius(DS.Radius.md)
                        .font(DS.Font.medium(12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!settings.isConfigured)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 420)
        .background(.clear)
    }
}

// MARK: - Settings Field Component

struct OutlinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(DS.Color.outline.opacity(0.3), lineWidth: 1)
            }
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String
    let hint: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.medium(12))
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if isSecure {
                SecureField("", text: $text)
                    .textFieldStyle(OutlinedTextFieldStyle())
            } else {
                TextField("", text: $text)
                    .textFieldStyle(OutlinedTextFieldStyle())
            }

            Text(hint)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
