//
//  ChatStore.swift
//  Local402
//
//  Observable chat state. Streams real tokens from the on-device `LLMEngine`
//  (via `LLMStore`). The model decides when to query the local RAG store (the
//  `search_documents` tool) or the paid web (`web_search`); retrieved sources
//  arrive as citations and are attached to the streaming message.
//
//  Transcript changes are reported to the owning `ConversationManager` at persist
//  checkpoints (user message, payment, finished/cancelled streaming) — never per
//  streamed token — so conversations survive across launches.
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

    /// The conversation this store is bound to. Persisted writes key off this id.
    let conversationID: UUID

    /// Called at meaningful checkpoints (user message appended, streaming finished,
    /// payment appended) so the owner can persist the transcript and refresh the
    /// sidebar. Never fired per streamed token, to avoid hammering the disk.
    var onConversationChanged: ((_ messages: [ChatMessage]) -> Void)?

    private let wallet: WalletStore
    private let llm: LLMStore
    private var streamTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ChatStore")

    /// Initializes from a persisted conversation: adopts its id, model, and
    /// transcript verbatim. An empty transcript is greeting-seeded so a freshly
    /// created conversation still opens with the assistant's intro.
    init(wallet: WalletStore, llm: LLMStore, conversation: Conversation) {
        self.wallet = wallet
        self.llm = llm
        self.modelName = conversation.modelName
        self.conversationID = conversation.id
        if conversation.messages.isEmpty {
            seedGreeting()
        } else {
            messages = conversation.messages
        }
    }

    /// Notifies the owner that the transcript changed at a persist checkpoint.
    private func notifyConversationChanged() {
        onConversationChanged?(messages)
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
        // Persist checkpoint: a user message (re)derives the title and updatedAt.
        notifyConversationChanged()

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
        // Persist checkpoint: keep whatever was streamed before the user stopped.
        notifyConversationChanged()
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
            //    inside this stream; retrieved sources arrive as citations and any
            //    x402 payment (paid web search) arrives as an inline payment pill.
            let stream = await llm.reply(
                userText: userText,
                onCitations: { [weak self] citations in
                    Task { @MainActor in self?.attachCitations(citations, to: messageID) }
                },
                onPayment: { [weak self] event in
                    Task { @MainActor in self?.attachPayment(event, to: messageID) }
                }
            )
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

    /// Appends an inline payment pill from a paid tool (e.g. `web_search` settled
    /// over x402), debits the shared wallet, and persists the transcript. The pill
    /// lands between text segments, so later tokens continue after it.
    private func attachPayment(_ event: PaymentEvent, to messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].segments.append(.payment(event))
        wallet.recordPayment(event)
        logger.debug("Agent paid \(event.amountLabel, privacy: .public) for \(event.label, privacy: .public)")
        // Persist checkpoint: a payment is a durable part of the transcript.
        notifyConversationChanged()
        // The user's USDC dropped on-chain; pull the fresh balance.
        Task { [wallet] in await wallet.refreshBalance() }
    }

    private func finishStreaming(messageID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].isStreaming = false
        }
        isStreaming = false
        streamTask = nil
        // Persist checkpoint: the completed assistant reply is now stable.
        notifyConversationChanged()
    }

    /// Builds segments from scripted beats immediately (used for the greeting).
    /// Retained for the payment-event seam: paid tools emit `.payment` segments
    /// from their results the same way.
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
