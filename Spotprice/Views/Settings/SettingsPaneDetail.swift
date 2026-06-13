//
//  SettingsPaneDetail.swift
//  Spotprice
//

import SwiftUI

struct SettingsPaneDetail: View {
    let pane: SettingsPane
    @Bindable var settings: ConsumptionSettings
    @Binding var connectionStatus: ConnectionStatus

    var body: some View {
        Form {
            paneContent
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch pane {
        case .overview:
            SettingsPriceAreaSection(settings: settings)
            SettingsEstimateSection(settings: settings)

        case .retail:
            RetailContractSection(settings: settings)

        case .grid:
            SettingsGridSection(settings: settings)

        case .consumption:
            SettingsConsumptionDataSection(
                settings: settings,
                connectionStatus: $connectionStatus
            )
            SettingsConsumptionVerificationSection(
                settings: settings,
                connectionStatus: $connectionStatus
            )

        case .history:
            SettingsHistoryStorageSection(settings: settings)

        case .advanced:
            SettingsAdvancedSection(settings: settings)
        }
    }
}