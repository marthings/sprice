//
//  Item.swift
//  SpotpriceApp
//
//  Created by Martin Berggren on 2026-05-19.
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
