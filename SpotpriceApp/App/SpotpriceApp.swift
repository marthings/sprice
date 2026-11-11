//
//  SpotpriceApp.swift
//  SpotpriceApp
//
//  Created by Martin Berggren on 2026-05-19.
//

import SwiftUI
import WidgetKit

@main
struct SpotpriceApp: App {
    init() {
        WidgetReload.timelines()
        DS.Font.configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .tint(DS.Color.accentText)
        }
    }
}
