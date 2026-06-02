//
//  CoinbaseConfig.swift
//  Local402
//
//  Public, non-secret configuration for the Coinbase integration. All secrets
//  (CDP API key, treasury key) live only on the BFF — never in the app.
//

import Foundation

enum CoinbaseConfig {
    /// Base URL of the backend-for-frontend that brokers all Coinbase calls.
    /// Local BFF for the live demo (run `npm run dev` in `bff/`). For a deployed
    /// BFF, swap in its HTTPS URL. NOTE: reaching `http://localhost` from the
    /// sandboxed app needs an ATS local-networking exception (or use an HTTPS
    /// tunnel and put that URL here).
    static let bffURL = URL(string: "http://localhost:8787")!

    /// Apple Pay merchant identifier (matches the app entitlement).
    static let merchantID = "merchant.tech.hiant.Local402"

    /// Settlement network for USDC + x402.
    static let network = "base"          // Base mainnet
    static let currencyCode = "USD"
    static let usdcDecimals = 6

    /// When true, every CoinbaseService call is served by the in-memory
    /// simulation (no BFF / keys / network). Keeps the UI demo working and is
    /// the live-demo safety net. Flip to false once the BFF + keys are wired.
    static let demoMode = false

    /// When true, Step 4 simulates the Apple Pay authorization instead of
    /// presenting the native PassKit sheet (which needs an Apple Merchant ID +
    /// signed build). Independent of `demoMode`: with `demoMode = false` and
    /// this `true`, wallet creation, balance, and x402 are all REAL — only the
    /// Apple Pay sheet is faked. Fund the wallet manually; after the simulated
    /// confirmation the app reads the real on-chain balance.
    static let simulateApplePay = true
}
