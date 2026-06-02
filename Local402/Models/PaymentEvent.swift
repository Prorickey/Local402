//
//  PaymentEvent.swift
//  Local402
//
//  A single x402 micropayment made by the agent (filler data).
//

import Foundation

struct PaymentEvent: Identifiable, Hashable {
    let id: UUID
    /// Amount in USDC.
    let amount: Decimal
    /// Human-readable description, e.g. "Web search API".
    let label: String
    /// The endpoint/resource the payment was for, e.g. "api.exa.ai/search".
    let resource: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        label: String,
        resource: String,
        timestamp: Date
    ) {
        self.id = id
        self.amount = amount
        self.label = label
        self.resource = resource
        self.timestamp = timestamp
    }

    var amountLabel: String {
        PaymentEvent.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()
}
