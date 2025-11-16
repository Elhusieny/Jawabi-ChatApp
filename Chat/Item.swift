//
//  Item.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 16/11/2025.
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
