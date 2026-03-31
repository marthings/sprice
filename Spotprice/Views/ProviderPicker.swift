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
            Text("Elbolag")
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
                Text("Välj din elleverantör för att få förbrukningsdata och mer exakta kostnadsberäkningar")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            } else {
                Text("Välj din elleverantör för förbrukningsdata")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ProviderPicker(selectedProviderId: .constant("vaggeryd"))
        .padding()
}
