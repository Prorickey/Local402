//
//  WalletStore.swift
//  Local402
//
//  Observable wallet state: balance, address, and recent payment history.
//  Backed by the in-memory mock seed in demo mode; in live mode the address is
//  adopted from a real CDP server wallet and the balance is refreshed on-chain.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class WalletStore {
    private(set) var wallet: WalletInfo
    private(set) var payments: [PaymentEvent]

    /// The real (or mock) wallet address, mirrored for convenient access by the
    /// chat + onboarding layers. Nil until a wallet has been provisioned/seeded.
    private(set) var address: String?

    private let coinbase: any CoinbaseServicing
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "WalletStore")

    /// `coinbase` defaults to the in-memory mock when omitted (keeps previews and
    /// direct inits compiling). It's resolved inside the main-actor init because
    /// `MockCoinbaseService` is main-actor isolated and so can't be a default arg.
    init(coinbase: (any CoinbaseServicing)? = nil, now: Date = Date()) {
        self.coinbase = coinbase ?? MockCoinbaseService()
        let seed = MockWallet.initialWallet()
        self.wallet = seed
        self.address = seed.address
        self.payments = MockWallet.seedPayments(now: now)
    }

    /// Adopts a freshly provisioned server wallet: stores its address and rebuilds
    /// `wallet` so the displayed address reflects the real on-chain account. The
    /// existing balance is preserved (live balance arrives via `refreshBalance`).
    func adoptWallet(_ wallet: ServerWallet) {
        self.address = wallet.address
        self.wallet = WalletInfo(
            balance: self.wallet.balance,
            address: wallet.address,
            currency: self.wallet.currency
        )
        logger.info("Adopted server wallet \(wallet.address, privacy: .public)")
    }

    /// Refreshes the on-chain USDC balance for the current address. No-op (other
    /// than logging) if there is no address yet. Errors are logged, not thrown —
    /// a stale balance must never crash the UI.
    func refreshBalance() async {
        guard let address else {
            logger.debug("refreshBalance skipped: no address yet")
            return
        }
        do {
            let balance = try await coinbase.balance(of: address)
            wallet = WalletInfo(
                balance: balance,
                address: wallet.address,
                currency: wallet.currency
            )
        } catch {
            logger.error("Failed to refresh balance: \(error.localizedDescription, privacy: .public)")
        }
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
