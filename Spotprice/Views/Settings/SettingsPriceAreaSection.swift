//
//  SettingsPriceAreaSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsPriceAreaSection: View {
    @Bindable var settings: ConsumptionSettings

    private let priceAreas = ["SE1", "SE2", "SE3", "SE4"]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Elområde")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            Picker("", selection: $settings[priceArea: SettingsBind.priceArea]) {
                ForEach(priceAreas, id: \.self) { area in
                    Text(area).tag(area)
                }
            }
            .labelsHidden()
            .pickerStyle(.palette)

            Text("Välj ditt elområde i Sverige. Detta räcker för att visa en första kostnadsuppskattning.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }
}