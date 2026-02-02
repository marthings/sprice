//
//  SpotpriceApp.swift
//  Spotprice
//

import SwiftUI
import WidgetKit

@main
struct SpotpriceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = SpotPriceViewModel()
    @StateObject private var summaryViewModel = SummaryViewModel()

    init() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        MenuBarExtra {
            ModernMenuBarView(viewModel: viewModel, summaryViewModel: summaryViewModel)
        } label: {
            MenuBarLabel(state: viewModel.state)
        }
        .menuBarExtraStyle(.window)
        .environmentObject(viewModel)
        .environmentObject(summaryViewModel)

        Settings {
            SettingsView()
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .toolbar(removing: .title)
        }
    }
}
