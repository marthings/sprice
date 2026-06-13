//
//  SettingsField.swift
//  Spotprice
//

import SwiftUI

struct SettingsField: View {
    let label: String
    @Binding var text: String
    let hint: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            LabeledContent(label) {
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: DS.Size.settingsFieldWidth)
            }

            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}