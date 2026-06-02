//
//  MessageSegment+Codable.swift
//  Local402
//
//  Explicit Codable conformance for the `MessageSegment` enum. The enum carries
//  associated values, so it is encoded as a tagged object: a `kind` discriminator
//  ("text" | "payment") plus the matching payload. This round-trips both cases
//  losslessly without touching the model's stored shape or its Identifiable id.
//

import Foundation

extension MessageSegment: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case text
        case payment
    }

    private enum Kind: String, Codable {
        case text
        case payment
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .text)
        case .payment(let event):
            try container.encode(Kind.payment, forKey: .kind)
            try container.encode(event, forKey: .payment)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .text:
            let value = try container.decode(String.self, forKey: .text)
            self = .text(value)
        case .payment:
            let event = try container.decode(PaymentEvent.self, forKey: .payment)
            self = .payment(event)
        }
    }
}
