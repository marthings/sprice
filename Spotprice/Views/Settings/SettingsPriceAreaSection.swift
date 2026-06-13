//
//  SettingsPriceAreaSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsPriceAreaSection: View {
    @Bindable var settings: ConsumptionSettings

    private let priceAreas = ["SE1", "SE2", "SE3", "SE4"]

    var body: some View {
        Section {
            Picker("Elområde", selection: $settings[priceArea: SettingsBind.priceArea]) {
                ForEach(priceAreas, id: \.self) { area in
                    Text(area).tag(area)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } footer: {
            Text("Välj ditt elområde i Sverige. Detta räcker för att visa en första kostnadsuppskattning.")
        }
    }
}