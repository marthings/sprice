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
                    NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Text("Välj ditt elområde i Sverige")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Provider selection
            ProviderPicker(selectedProviderId: $settings.selectedProviderId)
                .onChange(of: settings.selectedProviderId) { _, _ in
                    connectionStatus = .unknown
                }

            Divider()

            // Provider-specific credential fields
            ProviderCredentialsSection(
                settings: settings,
                providerId: settings.selectedProviderId
            )

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

#Preview {
    SettingsView()
}
