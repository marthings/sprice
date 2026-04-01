//
//  SummaryViewModel+State.swift
//  Spotprice
//

import Foundation

extension SummaryViewModel.State {
    var isLoading: Bool {
        switch self {
        case .loadingConsumption, .analyzing:
            return true
        default:
            return false
        }
    }
}
