//
//  ChartConfiguration.swift
//  Spotprice
//

import SwiftUI

enum ChartConfiguration {
    case menuBar
    case fullSize

    var height: CGFloat {
        switch self {
        case .menuBar: return 160
        case .fullSize: return 300
        }
    }

    var showXAxisLabels: Bool { true }
    var showYAxisLabels: Bool { true }

    var cornerRadius: CGFloat {
        switch self {
        case .menuBar: return 10
        case .fullSize: return 16
        }
    }
}
