//
//  SettingsSummaryRow.swift
//  Spotprice
//

import SwiftUI

struct SettingsSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
    }
}