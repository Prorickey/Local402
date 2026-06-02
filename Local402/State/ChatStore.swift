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
    private var userTurns = 0
    private var streamTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ChatStore")

    init(wallet: WalletStore, modelName: String) {
        self.wallet = wallet
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

        let beats = MockChat.reply(forUserTurn: userTurns)
        startStreaming(beats: beats)
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
                appendPayment(paymentBeat, into: messageID)
            }
        }

        finishStreaming(messageID: messageID)
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

    private func appendPayment(_ beat: PaymentBeat, into messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let event = PaymentEvent(
            amount: beat.amount,
            label: beat.label,
            resource: beat.resource,
            timestamp: Date()
        )
        messages[index].segments.append(.payment(event))
        wallet.recordPayment(event)
        logger.debug("Agent paid \(event.amountLabel, privacy: .public) for \(event.label, privacy: .public)")
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
