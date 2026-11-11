//
//  SpotpriceApp.swift
//  Spotprice
//

import SwiftUI
import WidgetKit

@main
struct SpotpriceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = SpotPriceViewModel()

    init() {
        WidgetReload.timelines()
#if DEBUG
        let missing = DS.Font.missingFonts()
        print(missing.isEmpty ? "Figtree: alla typsnitt laddade" : "Figtree saknas: \(missing)")
#endif
    }

    var body: some Scene {
        MenuBarExtra {
            ModernMenuBarView(viewModel: viewModel)
                .font(DS.Font.regular(13))
                .tint(DS.Color.accent)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .font(DS.Font.regular(13))
                .tint(DS.Color.accent)
        }
    }
}
