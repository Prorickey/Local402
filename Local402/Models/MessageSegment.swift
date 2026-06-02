//
//  MessageSegment.swift
//  Local402
//
//  A piece of an assistant/user message: either text or an inline payment event.
//

import Foundation

enum MessageSegment: Identifiable, Hashable {
    case text(String)
    case payment(PaymentEvent)

    var id: String {
        switch self {
        case .text(let value): return "text-\(value.hashValue)"
        case .payment(let event): return "payment-\(event.id.uuidString)"
        }
    }
}
