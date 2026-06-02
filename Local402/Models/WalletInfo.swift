//
//  WalletInfo.swift
//  Local402
//
//  Wallet status: balance and address (filler data).
//

import Foundation

struct WalletInfo: Hashable {
    /// Balance in USDC.
    var balance: Decimal
    let address: String
    let currency: String

    init(balance: Decimal, address: String, currency: String = "USDC") {
        self.balance = balance
        self.address = address
        self.currency = currency
    }

    var balanceLabel: String {
        let formatted = WalletInfo.balanceFormatter.string(from: balance as NSDecimalNumber) ?? "0.00"
        return "\(formatted) \(currency)"
    }

    /// Address truncated for display, e.g. `0x7a3f…9c21`.
    var shortAddress: String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    static let balanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
