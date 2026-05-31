//
//  ConnectionStatus.swift
//  Spotprice
//

import Foundation

enum ConnectionStatus: Equatable {
    case unknown      // Ännu ej testad
    case testing      // Testar...
    case connected    // API svarade 200
    case failed(String)  // Fel med meddelande
}
