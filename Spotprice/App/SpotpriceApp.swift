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
            ModernMenuBarView(
                state: viewModel.state,
                costProfile: ConsumptionSettings.shared.costProfile,
                currentTariff: viewModel.currentTariff,
                monthlyConsumption: viewModel.monthlyConsumption,
                powerPeaks: viewModel.powerPeaks,
                consumptionError: viewModel.consumptionError,
                preciseMonthlyCost: viewModel.preciseMonthlyCost,
                currentMonthHistorySummary: viewModel.currentMonthHistorySummary
            )
        } label: {
            MenuBarLabel(state: viewModel.state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
