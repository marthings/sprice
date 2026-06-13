//
//  SettingsAdvancedSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsAdvancedSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Avancerat")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            SettingsSummaryRow(title: "Energiskatt", value: energyTaxText)
            SettingsSummaryRow(title: "Elcertifikat", value: "1,75 öre/kWh")

            Toggle("Effektavgift", isOn: $settings[effectTariffEnabled: SettingsBind.effectTariffEnabled])
                .font(DS.Font.regular(11))

            if settings.costProfile.effectTariff != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effektavgift (kr/kW/mån)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    TextField("0", value: $settings[effectTariffPrice: SettingsBind.effectTariffPrice], format: .number)
                        .textFieldStyle(.roundedBorder)
                        .help("Ange bara detta om ditt elnätsbolag använder effektavgift.")
                }
            }

            Text("Effektavgift används bara om ditt elnätsbolag har det.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)

            Text(taxInfoText)
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
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