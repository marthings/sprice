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
        // Loads the settings, and the saved choice of example data, before anything reads data.
        let settings = ConsumptionSettings.shared
#if DEBUG
        // DEBUG only: `-DemoMode on` or `-DemoMode off` for screenshots, and `-DemoOffAfter 20`
        // switches example data off again after that many seconds, to test turning it off.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-DemoMode"), arguments.indices.contains(index + 1) {
            settings.setDemoMode(arguments[index + 1] == "on")
        }
        if let seconds = DebugLaunch.value(after: "-DemoOffAfter") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                settings.setDemoMode(false)
            }
        }
#endif
        WidgetReload.timelines()
        DS.Font.configureNavigationBarAppearance()
#if DEBUG
        let missing = DS.Font.missingFonts()
        print(missing.isEmpty ? "Manrope: alla typsnitt laddade" : "Manrope saknas: \(missing)")
#endif
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .font(DS.Font.regular(17))
                .tint(DS.Color.accentText)
        }
    }
}
