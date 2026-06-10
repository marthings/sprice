//
//  SpotpriceWidgetBundle.swift
//  SpotpriceWidget
//
//  Created by Martin Berggren on 2026-01-31.
//

import WidgetKit
import SwiftUI

@main
struct SpotpriceWidgetBundle: WidgetBundle {
    init() {
        DS.Font.registerBundledFonts()
    }

    var body: some Widget {
        SpotpriceWidget()
    }
}
