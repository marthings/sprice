//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI
import WidgetKit

enum ConnectionStatus: Equatable {
    case unknown      // Ännu ej testad
    case testing      // Testar...
    case connected    // API svarade 200
    case failed(String)  // Fel med meddelande
}

struct SettingsView: View {
    @ObservedObject var settings = ConsumptionSettings.shared
    @State private var selectedPriceArea = "SE3"
    @State private var connectionStatus: ConnectionStatus = .unknown

    private let priceAreas = ["SE1", "SE2", "SE3", "SE4"]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Prisområde
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Prisområde")
                    .font(DS.Font.bold(12))
                    .foregroundStyle(.primary)

                Picker("", selection: $selectedPriceArea) {
                    ForEach(priceAreas, id: \.self) { area in
                        Text(area).tag(area)
                    }
                }
                .pickerStyle(.palette)
                .onChange(of: selectedPriceArea) { _, newValue in
                    settings.priceArea = newValue
                    // Ladda om priser direkt vid byte av område
                    NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Text("Välj ditt elområde i Sverige")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            Divider()

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
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Öppna Mina Sidor i Chrome")
                    Text("2. Logga in och gå till statistik")
                    Text("3. Öppna DevTools (Cmd+Option+I)")
                    Text("4. Gå till Network-fliken")
                    Text("5. Ladda om sidan och klicka på en \"1\"-request")
                    Text("6. Under Headers → :path hittar du:")
                }
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)


                Text(".../monthly/[Konto-ID]/[Anläggnings-ID]/...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(DS.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: .rect(cornerRadius: DS.Radius.sm))

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
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: DS.Radius.md))


            // Footer
            HStack(spacing: 8) {
                Group {
                    switch connectionStatus {
                    case .unknown:
                        if settings.isConfigured {
                            Label("Verifiera dina uppgifter genom att spara", systemImage: "questionmark.circle.fill")
                                .foregroundStyle(DS.Color.warning)
                        } else {
                            Label("Ej konfigurerad", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(DS.Color.warning)
                        }
                    case .testing:
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7)
                            Text("Testar...")
                        }
                        .foregroundStyle(.secondary)
                    case .connected:
                        Label("Kopplad!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.success)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(DS.Color.danger)
                    }
                }
                .font(DS.Font.caption)

                Spacer()

                Button {
                    Task {
                        connectionStatus = .testing
                        do {
                            try await ConsumptionService().testConnection()
                            connectionStatus = .connected
                            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                            WidgetCenter.shared.reloadAllTimelines()
                        } catch {
                            connectionStatus = .failed(error.localizedDescription)
                        }
                    }
                } label: {
                    Text("Spara")
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .font(DS.Font.bold(12))
                        .foregroundStyle(.white)
                        .background(DS.Color.brand, in: .rect(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(!settings.isConfigured || connectionStatus == .testing)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .onAppear {
            selectedPriceArea = settings.priceArea
        }
    }
}

// MARK: - Settings Field Component

struct OutlinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(DS.Color.outline.opacity(0.4), lineWidth: 1)
            }
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String
    let hint: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.bold(12))
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
