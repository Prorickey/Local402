//
//  Item.swift
//  Local402
//
//  Created by Trevor Bedson on 6/2/26.
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
