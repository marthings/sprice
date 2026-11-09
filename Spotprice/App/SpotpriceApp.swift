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
    }

    var body: some Scene {
        MenuBarExtra {
            ModernMenuBarView(viewModel: viewModel)
                .tint(DS.Color.accent)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .tint(DS.Color.accent)
        }
    }
}
