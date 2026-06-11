//
//  SpotpriceAppApp.swift
//  SpotpriceApp
//
//  Created by Martin Berggren on 2026-05-19.
//

import SwiftUI
import WidgetKit

@main
struct SpotpriceAppApp: App {
    init() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}
