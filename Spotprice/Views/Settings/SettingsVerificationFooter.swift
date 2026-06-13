//
//  SettingsVerificationFooter.swift
//  Spotprice
//

import SwiftUI
import WidgetKit
import OSLog

struct SettingsConsumptionVerificationSection: View {
    @Bindable var settings: ConsumptionSettings
    @Binding var connectionStatus: ConnectionStatus

    var body: some View {
        Section {
            LabeledContent("Anslutning", value: statusText)

            Button("Verifiera") {
                verifyConnection()
            }
            .disabled(!settings.isConfigured || connectionStatus == .testing)
        } footer: {
            Text("Testa att appen kan hämta förbrukningsdata från din valda datakälla.")
        }
    }

    private var statusText: String {
        switch connectionStatus {
        case .unknown:
            return settings.isConfigured
                ? "Redo att verifieras"
                : "Ej konfigurerad"
        case .testing:
            return "Testar..."
        case .connected:
            return "Kopplad"
        case .failed(let message):
            return message
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