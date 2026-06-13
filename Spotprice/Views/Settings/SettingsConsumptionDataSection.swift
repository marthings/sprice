//
//  SettingsConsumptionDataSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsConsumptionDataSection: View {
    @Bindable var settings: ConsumptionSettings
    @Binding var connectionStatus: ConnectionStatus

    var body: some View {
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

        if !settings.selectedProviderId.isEmpty {
            ProviderCredentialsSection(
                settings: settings,
                providerId: settings.selectedProviderId
            )
        }
    }
}