//
//  SettingsPane.swift
//  Spotprice
//

import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case overview
    case retail
    case grid
    case consumption
    case history
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Översikt"
        case .retail: return "Elhandel"
        case .grid: return "Elnät"
        case .consumption: return "Förbrukning"
        case .history: return "Historik"
        case .advanced: return "Avancerat"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .retail: return "bolt.fill"
        case .grid: return "powerplug.fill"
        case .consumption: return "gauge.with.needle.fill"
        case .history: return "clock.arrow.circlepath"
        case .advanced: return "slider.horizontal.3"
        }
    }
}