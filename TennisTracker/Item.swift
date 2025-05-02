//
//  Item.swift
//  TennisTracker
//
//  Created by Kavin Rajasekaran on 2025-05-01.
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
