//
//  SettingsSummaryRow.swift
//  Spotprice
//

import SwiftUI

struct SettingsSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(DS.Font.regular(11))
            Spacer()
            Text(value)
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }
}