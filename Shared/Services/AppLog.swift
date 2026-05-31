//
//  AppLog.swift
//  Spotprice
//

import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "mb.Spotprice"

    static let spotPrice = Logger(subsystem: subsystem, category: "SpotPrice")
    static let history = Logger(subsystem: subsystem, category: "History")
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")
    static let widget = Logger(subsystem: subsystem, category: "Widget")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
