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
        Section {
            Picker("Datakälla", selection: $selectedProviderId) {
                Text("Ingen vald").tag("")
                ForEach(providers) { provider in
                    Text(provider.displayName).tag(provider.identifier)
                }
            }
        } footer: {
            if selectedProviderId.isEmpty {
                Text("Valfritt. Välj en datakälla om du vill hämta förbrukning automatiskt. Detta krävs inte för kostnadsberäkning.")
            } else {
                Text("Datakällan används för förbrukningsdata, inte som krav för kostnadsberäkning.")
            }
        }
    }
}

#Preview {
    Form {
        ProviderPicker(selectedProviderId: .constant("vaggeryd"))
    }
    .formStyle(.grouped)
    .frame(width: 420)
}