//
//  ProviderPicker.swift
//  Spotprice
//
//  Provider selection picker for settings
//

import SwiftUI

struct ProviderPicker: View {
    @Binding var selectedProviderId: String

    private let providers = ProviderRegistry.shared.allProviderMetadata()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Datakälla")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            Picker("", selection: $selectedProviderId) {
                Text("Ingen vald").tag("")
                ForEach(providers) { provider in
                    Text(provider.displayName).tag(provider.identifier)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if selectedProviderId.isEmpty {
                Text("Valfritt. Välj en datakälla om du vill hämta förbrukning automatiskt.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                Text("Datakällan används för förbrukningsdata, inte som krav för kostnadsberäkning.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
    }
}

#Preview {
    ProviderPicker(selectedProviderId: .constant("vaggeryd"))
        .padding()
}
