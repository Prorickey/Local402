//
//  MockCoinbaseService.swift
//  Local402
//
//  In-memory simulation of `CoinbaseServicing` used when `CoinbaseConfig.demoMode`
//  is true (no BFF / keys / network). All values are deterministic — hashes and
//  addresses are derived from an incrementing counter plus the inputs, never from
//  `Date.now` or any random source — so demo runs are reproducible.
//

import Foundation
import os

/// Deterministic, network-free stand-in for the live Coinbase service.
///
/// The type is `@MainActor`-isolated by default (project setting
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), so its mutable state is
/// accessed serially on the main actor.
final class MockCoinbaseService: CoinbaseServicing {
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "MockCoinbaseService")

    /// Monotonic counter that seeds every fabricated address / tx hash so output
    /// is unique-per-call yet fully deterministic across runs.
    private var counter: UInt64 = 0

    /// Simulated on-chain USDC balances keyed by wallet address. Starts empty;
    /// `fund` adds, `payX402` subtracts.
    private var balances: [String: Decimal] = [:]

    // MARK: - Simulated latency (nanoseconds)

    private enum Delay {
        static let createWallet: UInt64 = 1_200_000_000  // ~1.2s
        static let fund: UInt64 = 1_500_000_000          // ~1.5s
        static let pay: UInt64 = 400_000_000             // ~0.4s
        static let search: UInt64 = 1_200_000_000        // ~1.2s
    }

    /// Fixed price of a simulated Tavily x402 search, mirroring the live BFF.
    private static let searchPrice = Decimal(string: "0.01") ?? 0

    /// Address of the most recently created wallet, debited by `search` since the
    /// search endpoint carries no explicit `from` address.
    private var lastWalletAddress: String?

    init() {}

    // MARK: - CoinbaseServicing

    func createServerWallet() async throws -> ServerWallet {
        try await sleep(Delay.createWallet)
        let seed = nextSeed()
        let address = Self.fabricatedAddress(seed: seed)
        let walletId = "wlt_demo_\(String(format: "%08x", seed))"
        balances[address] = 0
        lastWalletAddress = address
        logger.debug("MockCoinbaseService created wallet \(address, privacy: .public)")
        return ServerWallet(address: address, walletId: walletId)
    }

    func balance(of address: String) async throws -> Decimal {
        balances[address] ?? 0
    }

    func fund(address: String, amountUSD: Decimal, applePayToken: Data?) async throws -> FundReceipt {
        try await sleep(Delay.fund)
        let seed = nextSeed()
        let current = balances[address] ?? 0
        balances[address] = current + amountUSD
        let txHash = Self.fabricatedHash(seed: seed, salt: address)
        logger.debug("MockCoinbaseService funded \(address, privacy: .public) credited=\(amountUSD.description, privacy: .public)")
        return FundReceipt(txHash: txHash, creditedUSD: amountUSD)
    }

    func payX402(_ envelope: X402Envelope, from address: String) async throws -> PaymentReceipt {
        try await sleep(Delay.pay)
        let seed = nextSeed()
        let current = balances[address] ?? 0
        balances[address] = current - envelope.amount
        let txHash = Self.fabricatedHash(seed: seed, salt: envelope.resource)
        logger.debug("MockCoinbaseService paid \(envelope.amount.description, privacy: .public) for \(envelope.resource, privacy: .public)")
        return PaymentReceipt(
            txHash: txHash,
            amount: envelope.amount,
            resource: envelope.resource,
            label: envelope.label
        )
    }

    func search(_ query: String) async throws -> SearchResult {
        try await sleep(Delay.search)
        let seed = nextSeed()

        // Debit the simulated balance of the most recently created wallet so the
        // demo pill/spend chip reflect the $0.01 micropayment.
        if let address = lastWalletAddress {
            let current = balances[address] ?? 0
            balances[address] = current - Self.searchPrice
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = trimmed.isEmpty ? "your topic" : trimmed
        let slug = Self.slug(from: topic)

        let answer = "Based on a quick Tavily search, here's a concise take on \(topic): "
            + "recent coverage is broadly consistent, with the most credible sources agreeing on the key points below."

        let hits = [
            SearchHit(
                title: "\(topic): a practical overview",
                url: "https://example.com/\(slug)-overview",
                content: "An accessible, up-to-date overview of \(topic), covering the essentials and recent developments.",
                score: 0.93
            ),
            SearchHit(
                title: "What the latest data says about \(topic)",
                url: "https://news.example.org/\(slug)-data",
                content: "A data-driven look at \(topic) with charts and primary-source citations from this quarter.",
                score: 0.87
            ),
            SearchHit(
                title: "\(topic) explained, with expert commentary",
                url: "https://docs.example.net/\(slug)-explained",
                content: "Expert commentary contextualizing \(topic) and outlining the most common misconceptions.",
                score: 0.81
            )
        ]

        let txHash = Self.fabricatedHash(seed: seed, salt: "x402.tavily.com/search")
        let payment = PaymentReceipt(
            txHash: txHash,
            amount: Self.searchPrice,
            resource: "x402.tavily.com/search",
            label: "Tavily search"
        )

        logger.debug("MockCoinbaseService searched for \(topic, privacy: .public)")
        return SearchResult(query: query, answer: answer, hits: hits, payment: payment)
    }

    // MARK: - Helpers

    /// Lowercase, hyphenated slug derived from arbitrary text for fake URLs.
    private static func slug(from text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let trimmed = collapsed.isEmpty ? "topic" : collapsed
        return String(trimmed.prefix(48))
    }

    private func sleep(_ nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    private func nextSeed() -> UInt64 {
        counter &+= 1
        return counter
    }

    /// Builds a `0x` + 40-hex-char address that varies deterministically with `seed`.
    private static func fabricatedAddress(seed: UInt64) -> String {
        "0x" + deterministicHex(seed: seed, salt: "wallet", length: 40)
    }

    /// Builds a `0x` + 64-hex-char transaction hash from `seed` and an input salt.
    private static func fabricatedHash(seed: UInt64, salt: String) -> String {
        "0x" + deterministicHex(seed: seed, salt: salt, length: 64)
    }

    /// Produces `length` lowercase hex characters deterministically from the seed
    /// and salt using a simple splitmix-style PRNG (no randomness source).
    private static func deterministicHex(seed: UInt64, salt: String, length: Int) -> String {
        var state = seed &+ 0x9E37_79B9_7F4A_7C15
        for byte in salt.utf8 {
            state = (state ^ UInt64(byte)) &* 0x100_0000_01B3
        }

        var hex = ""
        hex.reserveCapacity(length)
        let alphabet = Array("0123456789abcdef")
        while hex.count < length {
            // SplitMix64 step.
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            for shift in stride(from: 60, through: 0, by: -4) where hex.count < length {
                let nibble = Int((z >> UInt64(shift)) & 0xF)
                hex.append(alphabet[nibble])
            }
        }
        return hex
    }
}
