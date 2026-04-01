//
//  SettingsField.swift
//  Spotprice
//

import SwiftUI

struct OutlinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: DS.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(DS.Color.outline.opacity(0.4), lineWidth: 1)
            }
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String
    let hint: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            if isSecure {
                SecureField("", text: $text)
                    .textFieldStyle(OutlinedTextFieldStyle())
            } else {
                TextField("", text: $text)
                    .textFieldStyle(OutlinedTextFieldStyle())
            }

            Text(hint)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
        }
    }
}
