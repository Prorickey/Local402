//
//  CoinbaseModels.swift
//  Local402
//
//  Domain types and the service protocol shared by the live + mock Coinbase
//  service implementations and by the state layer. Wire (Codable DTO) types
//  live in the concrete service, not here.
//

import Foundation

/// A CDP server wallet provisioned by the BFF on the user's behalf.
struct ServerWallet: Sendable, Hashable {
    let address: String
    /// Opaque CDP wallet/account id (BFF-side handle). May be empty in demo mode.
    let walletId: String
}

/// Result of funding the user's wallet (treasury → user USDC transfer on Base).
struct FundReceipt: Sendable, Hashable {
    let txHash: String
    /// USD amount credited as USDC.
    let creditedUSD: Decimal
}

/// An x402 "Payment Required" envelope parsed from a 402 response.
struct X402Envelope: Sendable, Hashable {
    /// Endpoint/resource that requires payment, e.g. "api.tavily.com/search".
    let resource: String
    /// Human-readable label, e.g. "Tavily search".
    let label: String
    /// Price in USDC.
    let amount: Decimal
    /// Recipient address.
    let payTo: String
    /// Settlement network, e.g. "base".
    let network: String
}

/// Result of settling an x402 payment via the facilitator.
struct PaymentReceipt: Sendable, Hashable {
    let txHash: String
    let amount: Decimal
    let resource: String
    let label: String
}

/// A single web result returned by a real Tavily x402 search.
struct SearchHit: Sendable, Hashable {
    let title: String
    let url: String
    let content: String
    let score: Double
}

/// Result of a real Tavily-over-x402 search: the hits plus the on-chain payment
/// that paid for them.
struct WebSearchResult: Sendable, Hashable {
    let query: String
    let answer: String?
    let hits: [SearchHit]
    /// The x402 micropayment that funded this search (real tx hash, $0.01).
    let payment: PaymentReceipt
}

enum CoinbaseServiceError: LocalizedError {
    case notReady
    case transport(String)
    case decoding
    case http(Int)
    case server(String)
    case applePayCancelled
    case applePayUnavailable

    var errorDescription: String? {
        switch self {
        case .notReady: return "Coinbase service is not ready."
        case .transport(let m): return "Network error: \(m)"
        case .decoding: return "Unexpected response from the server."
        case .http(let code): return "Server returned HTTP \(code)."
        case .server(let m): return m
        case .applePayCancelled: return "Apple Pay was cancelled."
        case .applePayUnavailable: return "Apple Pay isn't available on this device."
        }
    }
}

/// Abstraction over the Coinbase integration. Implemented by `LiveCoinbaseService`
/// (talks to the BFF) and `MockCoinbaseService` (in-memory simulation for DEMO_MODE).
///
/// Note: Apple Pay presentation is handled separately by `ApplePayFundingController`
/// (PassKit, @MainActor). `fund(...)` performs only the BFF treasury transfer given
/// an already-authorized Apple Pay token (or nil in demo mode).
protocol CoinbaseServicing: Sendable {
    /// Silently provisions a CDP server wallet for the user.
    func createServerWallet() async throws -> ServerWallet

    /// Current on-chain USDC balance for `address`.
    func balance(of address: String) async throws -> Decimal

    /// Delivers `amountUSD` of USDC to `address` from the BFF treasury. The Apple
    /// Pay token is forwarded for audit but not captured (no PSP) in this build.
    func fund(address: String, amountUSD: Decimal, applePayToken: Data?) async throws -> FundReceipt

    /// Signs (server wallet, EIP-3009) + settles an x402 payment via the facilitator.
    func payX402(_ envelope: X402Envelope, from address: String) async throws -> PaymentReceipt

    /// Performs a REAL Tavily web search paid over x402 from the user's wallet
    /// (BFF `POST /tools/search`). Returns the real results + the settlement.
    func search(_ query: String) async throws -> WebSearchResult
}
