//
//  SettingsVerificationFooter.swift
//  Spotprice
//

import SwiftUI
import WidgetKit
import OSLog

struct SettingsVerificationFooter: View {
    @Bindable var settings: ConsumptionSettings
    @Binding var connectionStatus: ConnectionStatus

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                Group {
                    switch connectionStatus {
                    case .unknown:
                        if settings.isConfigured {
                            Label("Förbrukningsdata redo att verifieras", systemImage: "questionmark.circle.fill")
                                .foregroundStyle(DS.Color.warning)
                        } else {
                            Label("Förbrukningsdata ej kopplad", systemImage: "bolt.horizontal.circle")
                                .foregroundStyle(DS.Color.secondary)
                        }
                    case .testing:
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7)
                            Text("Testar...")
                        }
                        .foregroundStyle(DS.Color.secondary)
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
                    verifyConnection()
                } label: {
                    Text("Verifiera")
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .font(DS.Font.bold(12))
                        .foregroundStyle(.white)
                        .background(DS.Color.brand, in: .rect(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(!settings.isConfigured || connectionStatus == .testing)
            }
            .padding(DS.Spacing.lg)
            .background(.background)
        }
    }

    private func verifyConnection() {
        Task {
            connectionStatus = .testing
            do {
                try await ConsumptionService().testConnection()
                connectionStatus = .connected

                settings.costProfile = settings.costProfile.updating(
                    confidence: .providerConnected,
                    source: .providerData
                )

                settings.cachedConsumption = nil

                NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)

                WidgetCenter.shared.reloadAllTimelines()

                AppLog.settings.info("Consumption provider verification succeeded")
            } catch {
                connectionStatus = .failed(error.userFacingMessage)
                AppLog.settings.error("Consumption provider verification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}