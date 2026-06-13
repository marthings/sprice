//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI

struct SettingsView: View {
    @Bindable var settings = ConsumptionSettings.shared
    @State private var connectionStatus: ConnectionStatus = .unknown

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    SettingsPriceAreaSection(settings: settings)
                    Divider()
                    SettingsEstimateSection(settings: settings)
                    Divider()
                    SettingsGridSection(settings: settings)
                    Divider()
                    RetailContractSection(settings: settings)
                    Divider()
                    SettingsConsumptionDataSection(
                        settings: settings,
                        connectionStatus: $connectionStatus
                    )
                    Divider()
                    SettingsHistoryStorageSection(settings: settings)
                    Divider()
                    SettingsAdvancedSection(settings: settings)
                }
                .padding(DS.Spacing.lg)
            }

            SettingsVerificationFooter(
                settings: settings,
                connectionStatus: $connectionStatus
            )
        }
        .frame(width: DS.Size.settingsWidth, height: 520)
    }
}

#Preview {
    SettingsView()
}