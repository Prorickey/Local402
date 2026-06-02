//
//  MockWallet.swift
//  Local402
//
//  Filler wallet status and seed payment history.
//

import Foundation

enum MockWallet {
    static let address = "0x7a3f4b2e9d1c8f5a6b0e2d4c9f1a8b3e7c0d6f21"

    static func initialWallet(balance: Decimal = 25.00) -> WalletInfo {
        WalletInfo(balance: balance, address: address)
    }

    /// A handful of recent payments seeded into the wallet history.
    /// `now` is passed in so timestamps are relative to launch.
    static func seedPayments(now: Date) -> [PaymentEvent] {
        [
            PaymentEvent(
                amount: 0.02,
                label: "Tavily search",
                resource: "api.tavily.com/search",
                timestamp: now.addingTimeInterval(-60 * 14)
            ),
            PaymentEvent(
                amount: 0.05,
                label: "Document OCR",
                resource: "ocr.nutrient.io/extract",
                timestamp: now.addingTimeInterval(-60 * 47)
            ),
            PaymentEvent(
                amount: 0.01,
                label: "Geocoding lookup",
                resource: "api.maps.dev/geocode",
                timestamp: now.addingTimeInterval(-60 * 92)
            ),
            PaymentEvent(
                amount: 0.12,
                label: "Market data feed",
                resource: "data.finance.io/quote",
                timestamp: now.addingTimeInterval(-60 * 60 * 5)
            ),
            PaymentEvent(
                amount: 0.03,
                label: "Code execution",
                resource: "sandbox.run/exec",
                timestamp: now.addingTimeInterval(-60 * 60 * 26)
            )
        ]
    }
}
