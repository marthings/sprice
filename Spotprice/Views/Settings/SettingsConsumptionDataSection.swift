//
//  SettingsConsumptionDataSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsConsumptionDataSection: View {
    @Bindable var settings: ConsumptionSettings
    @Binding var connectionStatus: ConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Förbrukningsdata")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            ProviderPicker(selectedProviderId: $settings.selectedProviderId)
                .onChange(of: settings.selectedProviderId) { _, newValue in
                    connectionStatus = .unknown
                    if newValue.isEmpty && settings.costProfile.confidence == .providerConnected {
                        settings.costProfile = settings.costProfile.applyingInferredConfidence(
                            preservingProviderConnected: false,
                            configuredSource: .userEntered
                        )
                    }
                }

            ProviderCredentialsSection(
                settings: settings,
                providerId: settings.selectedProviderId
            )

            Text("Detta är valfritt. Koppla en datakälla för månadstatistik, dygnsförbrukning och mer precisa insikter.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }
}