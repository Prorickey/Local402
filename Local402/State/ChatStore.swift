//
//  ChatStore.swift
//  Local402
//
//  Observable chat state. Streams real tokens from the on-device `LLMEngine`
//  (via `LLMStore`). The model decides when to query the local RAG store (the
//  `search_documents` tool); retrieved sources arrive as citations and are
//  attached to the streaming message.
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

    private let wallet: WalletStore
    private let llm: LLMStore
    private var streamTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ChatStore")

    init(wallet: WalletStore, llm: LLMStore) {
        self.wallet = wallet
        self.llm = llm
        self.modelName = llm.modelName
        seedGreeting()
    }

    private func seedGreeting() {
        let beats = MockChat.greeting(modelName: modelName)
        let segments = ChatStore.segments(from: beats, wallet: nil, now: Date())
        messages = [ChatMessage(role: .assistant, segments: segments, timestamp: Date())]
    }

    /// Sends the current draft (or a provided text), then streams the model reply.
    func send(_ text: String? = nil) {
        let content = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isStreaming else { return }

        draft = ""
        messages.append(.text(content, role: .user, timestamp: Date()))
        startStreaming(userText: content)
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

    private func startStreaming(userText: String) {
        isStreaming = true
        let assistant = ChatMessage(role: .assistant, segments: [], timestamp: Date(), isStreaming: true)
        messages.append(assistant)
        let messageID = assistant.id

        streamTask = Task { [weak self] in
            await self?.runStream(userText: userText, messageID: messageID)
        }
    }

    private func runStream(userText: String, messageID: UUID) async {
        do {
            // 1. Make sure the model is downloaded + loaded (idempotent).
            try await llm.ensureReady()

            // 2. Stream tokens. The model may call search_documents / web_search
            //    inside this stream; retrieved sources arrive as citations.
            let stream = await llm.reply(userText: userText) { [weak self] citations in
                Task { @MainActor in self?.attachCitations(citations, to: messageID) }
            }
            for try await chunk in stream {
                if Task.isCancelled { break }
                appendText(chunk, into: messageID)
            }
        } catch is CancellationError {
            // User stopped generation — keep whatever streamed so far.
        } catch {
            logger.error("LLM stream failed: \(error.localizedDescription, privacy: .public)")
            appendText("\n\n⚠️ \(error.localizedDescription)", into: messageID)
        }

        finishStreaming(messageID: messageID)
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

    /// Adds newly retrieved sources to a message, de-duplicated by chunk id.
    private func attachCitations(_ citations: [Citation], to messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        var merged = messages[index].citations
        for citation in citations where !merged.contains(where: { $0.id == citation.id }) {
            merged.append(citation)
        }
        messages[index].citations = merged
    }

    private func finishStreaming(messageID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].isStreaming = false
        }
        isStreaming = false
        streamTask = nil
    }

    /// Builds segments from scripted beats immediately (used for the greeting).
    /// Retained for the payment-event seam: once paid tools settle over x402,
    /// `.payment` segments will be emitted from tool results the same way.
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
