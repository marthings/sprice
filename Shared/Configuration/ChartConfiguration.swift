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
        case .menuBar: return DS.Size.chartHeightMenuBar
        case .fullSize: return DS.Size.chartHeightFull
        }
    }

    var showXAxisLabels: Bool { true }
    var showYAxisLabels: Bool { true }

    var cornerRadius: CGFloat {
        switch self {
        case .menuBar: return DS.Radius.sm
        case .fullSize: return DS.Radius.lg
        }
    }
}
