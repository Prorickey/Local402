//
//  WalletStore.swift
//  Local402
//
//  Observable wallet state: balance, address, and recent payment history.
//

import Foundation
import Observation

@Observable
final class WalletStore {
    private(set) var wallet: WalletInfo
    private(set) var payments: [PaymentEvent]

    init(now: Date = Date()) {
        self.wallet = MockWallet.initialWallet()
        self.payments = MockWallet.seedPayments(now: now)
    }

    /// Records a payment: debits the balance and prepends it to the history.
    func recordPayment(_ payment: PaymentEvent) {
        wallet.balance -= payment.amount
        payments.insert(payment, at: 0)
    }

    /// Adds funds to the wallet (used by the onboarding funding step).
    func addFunds(_ amount: Decimal) {
        wallet.balance += amount
    }

    /// Total spent across all recorded payments.
    var totalSpent: Decimal {
        payments.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalSpentLabel: String {
        let value = PaymentEvent.currencyFormatter.string(from: totalSpent as NSDecimalNumber) ?? "$0.00"
        return value
    }
}
