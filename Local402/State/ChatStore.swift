//
//  ChatStore.swift
//  Local402
//
//  Observable chat state with a simulated, cancellable streaming reply that
//  emits inline payment events and debits the shared WalletStore.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class ChatStore {
    private(set) var messages: [ChatMessage] = []
    var draft: String = ""
    private(set) var isStreaming = false

    /// The agent's model name, shown in the greeting and header.
    var modelName: String

    /// Spend posture for the agent: 0 Frugal, 1 Balanced, 2 Thorough.
    /// Drives the Copilot-style spend-mode selector in the chat header.
    var spendMode: Int = 1

    private let wallet: WalletStore
    private let coinbase: any CoinbaseServicing
    private var userTurns = 0
    private var streamTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ChatStore")

    init(
        wallet: WalletStore,
        coinbase: (any CoinbaseServicing)? = nil,
        modelName: String
    ) {
        self.wallet = wallet
        // Resolved in the main-actor init: `MockCoinbaseService` is main-actor
        // isolated and so can't be a default argument.
        self.coinbase = coinbase ?? MockCoinbaseService()
        self.modelName = modelName
        seedGreeting()
    }

    private func seedGreeting() {
        let beats = MockChat.greeting(modelName: modelName)
        let segments = ChatStore.segments(from: beats, wallet: nil, now: Date())
        messages = [ChatMessage(role: .assistant, segments: segments, timestamp: Date())]
    }

    /// Sends the current draft (or a provided text), then streams a scripted reply.
    func send(_ text: String? = nil) {
        let content = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isStreaming else { return }

        draft = ""
        userTurns += 1
        messages.append(.text(content, role: .user, timestamp: Date()))

        if CoinbaseConfig.demoMode {
            // DEMO: scripted beats (fabricated payments, no network).
            let beats = MockChat.reply(forUserTurn: userTurns)
            startStreaming(beats: beats)
        } else {
            // LIVE: drive a real Tavily-over-x402 search for this user message.
            startLiveSearch(query: content)
        }
    }

    /// Cancels any in-flight streaming reply.
    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].isStreaming = false
        }
    }

    private func startStreaming(beats: [ReplyBeat]) {
        isStreaming = true
        let assistant = ChatMessage(role: .assistant, segments: [], timestamp: Date(), isStreaming: true)
        messages.append(assistant)
        let messageID = assistant.id

        streamTask = Task { [weak self] in
            await self?.runStream(beats: beats, messageID: messageID)
        }
    }

    private func runStream(beats: [ReplyBeat], messageID: UUID) async {
        // Brief "thinking" pause before the first token.
        try? await Task.sleep(for: .milliseconds(450))

        for beat in beats {
            if Task.isCancelled { break }

            switch beat {
            case .text(let chunk):
                await streamText(chunk, into: messageID)
            case .payment(let paymentBeat):
                try? await Task.sleep(for: .milliseconds(500))
                await appendPayment(paymentBeat, into: messageID)
            }
        }

        finishStreaming(messageID: messageID)
    }

    // MARK: - Live search

    /// Starts a streaming assistant reply backed by a REAL Tavily-over-x402
    /// search. Mirrors `startStreaming` but runs the live search driver instead
    /// of replaying scripted beats.
    private func startLiveSearch(query: String) {
        isStreaming = true
        let assistant = ChatMessage(role: .assistant, segments: [], timestamp: Date(), isStreaming: true)
        messages.append(assistant)
        let messageID = assistant.id

        streamTask = Task { [weak self] in
            await self?.runLiveSearch(query: query, messageID: messageID)
        }
    }

    /// Performs a real search and streams an intro line, the real payment pill,
    /// and a synthesis of the results. The stream is fully cancellable and never
    /// crashes: any failure becomes a graceful, payment-free fallback line.
    private func runLiveSearch(query: String, messageID: UUID) async {
        // Brief "thinking" pause before the first token (matches scripted path).
        try? await Task.sleep(for: .milliseconds(450))
        if Task.isCancelled {
            finishStreaming(messageID: messageID)
            return
        }

        await streamText("Let me search the web with Tavily for that. ", into: messageID)
        if Task.isCancelled {
            finishStreaming(messageID: messageID)
            return
        }

        let result: SearchResult
        do {
            result = try await coinbase.search(query)
        } catch {
            logger.error("Live search failed for query: \(error.localizedDescription, privacy: .public)")
            await streamText(
                "I couldn't reach the web just now — \(error.localizedDescription)",
                into: messageID
            )
            finishStreaming(messageID: messageID)
            return
        }

        if Task.isCancelled {
            finishStreaming(messageID: messageID)
            return
        }

        // Real payment pill built from the on-chain receipt (not fabricated).
        try? await Task.sleep(for: .milliseconds(500))
        appendRealPayment(result.payment, into: messageID)

        if Task.isCancelled {
            finishStreaming(messageID: messageID)
            return
        }

        await streamSynthesis(of: result, into: messageID)

        finishStreaming(messageID: messageID)

        // The user's USDC dropped by the search price on-chain; pull the fresh
        // balance so the wallet reflects the real debit.
        Task { [wallet] in
            await wallet.refreshBalance()
        }
    }

    /// Streams a human-readable synthesis: the optional Tavily answer followed by
    /// the top results as `title — short snippet (url)`.
    private func streamSynthesis(of result: SearchResult, into messageID: UUID) async {
        if let answer = result.answer, !answer.isEmpty {
            await streamText("\n\n" + answer, into: messageID)
        }

        let topHits = result.hits.prefix(3)
        guard !topHits.isEmpty else {
            if result.answer == nil || result.answer?.isEmpty == true {
                await streamText("\n\nI didn't find any solid web results for that.", into: messageID)
            }
            return
        }

        await streamText("\n\nTop results:", into: messageID)
        for hit in topHits {
            if Task.isCancelled { return }
            let snippet = ChatStore.shortSnippet(hit.content)
            await streamText("\n• \(hit.title) — \(snippet) (\(hit.url))", into: messageID)
        }
    }

    /// Trims a result snippet to a readable single line (~140 chars).
    private static func shortSnippet(_ content: String) -> String {
        let collapsed = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 140 else { return collapsed }
        return String(collapsed.prefix(140)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Appends a payment pill from a REAL settlement receipt and records it
    /// against the wallet. Mirrors `appendPayment` but uses the receipt's real
    /// amount/label/resource (the tx hash is carried by the receipt; the pill
    /// renders amount/label/resource today).
    private func appendRealPayment(_ receipt: PaymentReceipt, into messageID: UUID) {
        let event = PaymentEvent(
            amount: receipt.amount,
            label: receipt.label,
            resource: receipt.resource,
            timestamp: Date()
        )
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].segments.append(.payment(event))
        wallet.recordPayment(event)
        logger.debug("Agent paid \(event.amountLabel, privacy: .public) for \(event.label, privacy: .public) (tx \(receipt.txHash, privacy: .public))")
    }

    /// Streams a text chunk word-by-word into the message's trailing text segment.
    private func streamText(_ chunk: String, into messageID: UUID) async {
        let words = chunk.split(separator: " ", omittingEmptySubsequences: false)
        for (offset, word) in words.enumerated() {
            if Task.isCancelled { return }
            let piece = offset == 0 ? String(word) : " " + word
            appendText(piece, into: messageID)
            try? await Task.sleep(for: .milliseconds(28))
        }
    }

    private func appendText(_ piece: String, into messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        var segments = messages[index].segments
        if case .text(let existing)? = segments.last {
            segments[segments.count - 1] = .text(existing + piece)
        } else {
            segments.append(.text(piece))
        }
        messages[index].segments = segments
    }

    /// Settles a scripted payment beat. In demo mode the payment is fabricated
    /// locally. In live mode it is settled as a real x402 payment via the
    /// Coinbase facilitator; on failure the text is kept but no payment pill is
    /// shown (the stream must never crash).
    private func appendPayment(_ beat: PaymentBeat, into messageID: UUID) async {
        let event: PaymentEvent
        if CoinbaseConfig.demoMode {
            event = PaymentEvent(
                amount: beat.amount,
                label: beat.label,
                resource: beat.resource,
                timestamp: Date()
            )
        } else {
            guard let settled = await settleLivePayment(beat) else { return }
            event = settled
        }

        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].segments.append(.payment(event))
        wallet.recordPayment(event)
        logger.debug("Agent paid \(event.amountLabel, privacy: .public) for \(event.label, privacy: .public)")
    }

    /// Synthesizes an x402 envelope from a scripted beat and settles it through
    /// the Coinbase facilitator, returning a PaymentEvent carrying the real tx
    /// hash, or nil on failure.
    private func settleLivePayment(_ beat: PaymentBeat) async -> PaymentEvent? {
        guard let address = wallet.address else {
            logger.error("Skipping live payment for \(beat.label, privacy: .public): no wallet address")
            return nil
        }
        let envelope = X402Envelope(
            resource: beat.resource,
            label: beat.label,
            amount: beat.amount,
            payTo: "",
            network: CoinbaseConfig.network
        )
        do {
            let receipt = try await coinbase.payX402(envelope, from: address)
            return PaymentEvent(
                amount: receipt.amount,
                label: receipt.label,
                resource: receipt.resource,
                timestamp: Date()
            )
        } catch {
            logger.error("x402 payment failed for \(beat.label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func finishStreaming(messageID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].isStreaming = false
        }
        isStreaming = false
        streamTask = nil
    }

    /// Builds segments from beats immediately (used for the non-streamed greeting).
    private static func segments(from beats: [ReplyBeat], wallet: WalletStore?, now: Date) -> [MessageSegment] {
        beats.map { beat in
            switch beat {
            case .text(let value):
                return .text(value)
            case .payment(let paymentBeat):
                let event = PaymentEvent(
                    amount: paymentBeat.amount,
                    label: paymentBeat.label,
                    resource: paymentBeat.resource,
                    timestamp: now
                )
                wallet?.recordPayment(event)
                return .payment(event)
            }
        }
    }
}
