//
//  SpotpriceAppWidgetExtensionBundle.swift
//  SpotpriceAppWidgetExtension
//
//  Created by Martin Berggren on 2026-06-09.
//

import WidgetKit
import SwiftUI

@main
struct SpotpriceAppWidgetExtensionBundle: WidgetBundle {
    init() {
        DS.Font.registerBundledFonts()
    }

    var body: some Widget {
        SpotpriceAppWidget()
    }
}
