//
//  SettingsAdvancedSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsAdvancedSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        Section {
            SettingsSummaryRow(title: "Skatt på el", value: energyTaxText)
            SettingsSummaryRow(title: "Elcertifikat", value: "1,75 öre/kWh")

            Toggle(EffectTariffCopy.toggleTitle, isOn: $settings.includeHypotheticalEffectTariff)
        } header: {
            Text("Skatt och avgifter")
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(EffectTariffCopy.explanation)
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
            return "Skatten på el sänktes till 45 öre/kWh från januari 2026."
        }
        return "Svenska standardvärden 2025 (uppskattade värden i beräkningar)"
    }
}