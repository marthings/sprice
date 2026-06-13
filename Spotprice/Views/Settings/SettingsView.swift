//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI

struct SettingsView: View {
    @Bindable var settings = ConsumptionSettings.shared
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var selectedPane: SettingsPane = .overview

    var body: some View {
        TabView(selection: $selectedPane) {
            ForEach(SettingsPane.allCases) { pane in
                Tab(pane.title, systemImage: pane.icon, value: pane) {
                    SettingsPaneDetail(
                        pane: pane,
                        settings: settings,
                        connectionStatus: $connectionStatus
                    )
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: DS.Size.settingsWidth, height: DS.Size.settingsHeight)
}