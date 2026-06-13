//
//  SettingsAdvancedSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsAdvancedSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        Section {
            SettingsSummaryRow(title: "Energiskatt", value: energyTaxText)
            SettingsSummaryRow(title: "Elcertifikat", value: "1,75 öre/kWh")

            Toggle("Effektavgift", isOn: $settings[effectTariffEnabled: SettingsBind.effectTariffEnabled])

            if settings.costProfile.effectTariff != nil {
                LabeledContent("Effektpris") {
                    HStack(spacing: DS.Spacing.xs) {
                        TextField("0", value: $settings[effectTariffPrice: SettingsBind.effectTariffPrice], format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: DS.Size.settingsFieldWidth)
                        Text("kr/kW/mån")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Skatt och avgifter")
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Effektavgift används bara om ditt elnätsbolag har det.")
                Text(taxInfoText)
            }
        }
    }

    private var energyTaxText: String {
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "45,0 öre/kWh"
        }
        return "54,88 öre/kWh"
    }

    private var taxInfoText: String {
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "Energiskatt sänktes till 45 öre/kWh från januari 2026"
        }
        return "Svenska standardvärden 2025 (uppskattade värden i beräkningar)"
    }
}