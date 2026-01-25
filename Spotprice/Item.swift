//
//  Item.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
