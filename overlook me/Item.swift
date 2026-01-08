//
//  Item.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/8/26.
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
