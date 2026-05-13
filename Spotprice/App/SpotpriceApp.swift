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
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        MenuBarExtra {
            ModernMenuBarView(viewModel: viewModel)
        } label: {
            MenuBarLabel(state: viewModel.state, tariff: viewModel.currentTariff)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .toolbar(removing: .title)
        }
    }
}
