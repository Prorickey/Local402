//
//  ConversationManager.swift
//  Local402
//
//  Owns the sidebar's ordered conversation summaries and the current selection,
//  and brokers between the live `ChatStore` and the disk-backed `ConversationStore`.
//
//  On init it loads persisted summaries (off the main actor via the store actor)
//  and guarantees at least one real, persisted conversation exists so the app
//  always opens into a genuine chat. Creating, selecting, and deleting conversations
//  all flow through here; transcript changes arrive via the active `ChatStore`'s
//  `onConversationChanged` callback and are debounced to disk.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class ConversationManager {
    /// Ordered (most-recent-first) sidebar summaries.
    private(set) var summaries: [ConversationSummary] = []

    /// The currently selected conversation id (drives the active sidebar row).
    private(set) var selectedID: UUID?

    /// Grouped view of `summaries` for the sidebar.
    var groups: [ConversationGroup] {
        ConversationGrouping.groups(from: summaries)
    }

    private let store = ConversationStore()
    private let wallet: WalletStore
    private let coinbase: any CoinbaseServicing
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ConversationManager")

    /// The live store for the selected conversation. Rebuilt on selection/creation.
    private(set) var chat: ChatStore

    /// Cache of full conversations we've materialized this session, keyed by id, so
    /// re-selecting a conversation restores its exact transcript without a disk read
    /// race against in-flight writes.
    private var conversations: [UUID: Conversation] = [:]

    /// Per-conversation debounce tasks for transcript persistence.
    private var saveTasks: [UUID: Task<Void, Never>] = [:]
    private static let saveDebounce: Duration = .milliseconds(400)

    init(wallet: WalletStore, coinbase: any CoinbaseServicing, defaultModelName: String) {
        self.wallet = wallet
        self.coinbase = coinbase

        // A placeholder chat so `chat` is non-optional before async load completes.
        // Replaced synchronously by `bootstrap()`'s outcome below.
        let placeholder = Conversation(
            title: Conversation.untitled,
            modelName: defaultModelName,
            createdAt: Date(),
            updatedAt: Date(),
            messages: []
        )
        let placeholderChat = ConversationManager.makeChat(for: placeholder, wallet: wallet, coinbase: coinbase)

        // All stored properties are assigned directly (no `self`-dependent subscript
        // mutation or method call) before `self` is fully initialized.
        self.conversations = [placeholder.id: placeholder]
        self.selectedID = placeholder.id
        self.chat = placeholderChat
        self.summaries = [ConversationSummary(placeholder)]

        // The placeholder may be replaced by the persisted history (or adopted as
        // the first real conversation if none exists) once the disk load returns.
        wireChat(placeholderChat, conversation: placeholder)
        Task { await bootstrap(placeholder: placeholder) }
    }

    // MARK: - Bootstrap

    /// Loads persisted summaries. If history exists, selects the most recent and
    /// discards the placeholder. Otherwise the placeholder becomes the first real,
    /// persisted conversation.
    private func bootstrap(placeholder: Conversation) async {
        let loaded = await store.loadSummaries()
        if loaded.isEmpty {
            // First launch: promote the placeholder to a persisted conversation,
            // capturing the greeting the chat store seeded into it.
            let seeded = placeholder.updating(messages: chat.messages)
            conversations[seeded.id] = seeded
            persist(seeded, reindex: true)
            logger.info("No persisted conversations; seeded first conversation")
            return
        }

        let ordered = loaded.sorted { $0.updatedAt > $1.updatedAt }
        summaries = ordered
        // The placeholder was never written to disk in this branch; just forget
        // it from the in-memory cache so it doesn't linger as a phantom entry.
        conversations.removeValue(forKey: placeholder.id)

        if let mostRecent = ordered.first {
            await load(id: mostRecent.id)
        }
    }

    // MARK: - Public actions

    /// Creates a fresh, greeting-seeded conversation, persists it, and selects it.
    func newChat(modelName: String? = nil) {
        let model = modelName ?? chat.modelName
        let conversation = Conversation(
            title: Conversation.untitled,
            modelName: model,
            createdAt: Date(),
            updatedAt: Date(),
            messages: []
        )
        conversations[conversation.id] = conversation
        let newStore = ConversationManager.makeChat(for: conversation, wallet: wallet, coinbase: coinbase)
        wireChat(newStore, conversation: conversation)
        chat = newStore
        selectedID = conversation.id

        // The greeting was seeded in the store; capture it as the initial transcript.
        let seeded = conversation.updating(messages: newStore.messages)
        conversations[conversation.id] = seeded
        persist(seeded, reindex: true)
        logger.info("Created new conversation \(conversation.id.uuidString, privacy: .public)")
    }

    /// Selects an existing conversation, loading its transcript and rebuilding the
    /// live chat store. No-op if already selected.
    func load(id: UUID) async {
        guard id != selectedID || chat.conversationID != id else { return }

        let conversation: Conversation
        if let cached = conversations[id] {
            conversation = cached
        } else if let loaded = await store.loadConversation(id: id) {
            conversations[id] = loaded
            conversation = loaded
        } else {
            logger.error("Selected conversation \(id.uuidString, privacy: .public) could not be loaded")
            return
        }

        let newStore = ConversationManager.makeChat(for: conversation, wallet: wallet, coinbase: coinbase)
        wireChat(newStore, conversation: conversation)
        chat = newStore
        selectedID = id
        logger.debug("Selected conversation \(id.uuidString, privacy: .public)")
    }

    /// Synchronous selection entry point for UI callers; dispatches the async load.
    func select(id: UUID) {
        Task { await load(id: id) }
    }

    /// Deletes a conversation, persists the removal, and re-selects a neighbor (or
    /// creates a fresh conversation if none remain).
    func delete(id: UUID) {
        summaries.removeAll { $0.id == id }
        conversations.removeValue(forKey: id)
        saveTasks.removeValue(forKey: id)?.cancel()

        let remaining = summaries
        Task {
            await store.delete(id: id)
            await store.saveIndex(remaining)
        }

        if selectedID == id {
            if let next = summaries.first {
                select(id: next.id)
            } else {
                newChat()
            }
        }
        logger.info("Deleted conversation \(id.uuidString, privacy: .public)")
    }

    /// Replaces the live chat with one for the given model on a brand-new
    /// conversation. Used by onboarding completion so the first real conversation
    /// adopts the chosen model. Reuses the current empty conversation when it is
    /// still untouched to avoid stranding an empty "New chat" entry.
    func startFreshConversation(modelName: String) {
        // If the current conversation is still an empty greeting, just retarget it.
        if isUntouched(chat) {
            let retargeted = Conversation(
                id: chat.conversationID,
                title: Conversation.untitled,
                modelName: modelName,
                createdAt: conversations[chat.conversationID]?.createdAt ?? Date(),
                updatedAt: Date(),
                messages: []
            )
            conversations[retargeted.id] = retargeted
            let newStore = ConversationManager.makeChat(for: retargeted, wallet: wallet, coinbase: coinbase)
            wireChat(newStore, conversation: retargeted)
            chat = newStore
            selectedID = retargeted.id
            persist(retargeted.updating(messages: newStore.messages), reindex: true)
            return
        }
        newChat(modelName: modelName)
    }

    // MARK: - Wiring + persistence

    /// True when a conversation has only the seeded assistant greeting and no user
    /// turns — i.e. nothing worth preserving across a retarget.
    private func isUntouched(_ store: ChatStore) -> Bool {
        !store.messages.contains { $0.role == .user }
    }

    /// Builds a `ChatStore` bound to a conversation (greeting-seeds if empty).
    private static func makeChat(
        for conversation: Conversation,
        wallet: WalletStore,
        coinbase: any CoinbaseServicing
    ) -> ChatStore {
        ChatStore(wallet: wallet, coinbase: coinbase, conversation: conversation)
    }

    /// Wires a chat store's change callback to debounced persistence + sidebar refresh.
    private func wireChat(_ store: ChatStore, conversation: Conversation) {
        let baseCreatedAt = conversation.createdAt
        let id = conversation.id
        store.onConversationChanged = { [weak self] messages in
            guard let self else { return }
            self.handleTranscriptChange(id: id, createdAt: baseCreatedAt, messages: messages)
        }
    }

    /// Folds a transcript change into the in-memory conversation, refreshes the
    /// sidebar summaries/order immediately, and debounces the disk write.
    private func handleTranscriptChange(id: UUID, createdAt: Date, messages: [ChatMessage]) {
        let previous = conversations[id]
        let updated = Conversation(
            id: id,
            title: Conversation.derivedTitle(from: messages, fallback: previous?.title ?? Conversation.untitled),
            modelName: previous?.modelName ?? chat.modelName,
            createdAt: previous?.createdAt ?? createdAt,
            updatedAt: Date(),
            messages: messages
        )
        conversations[id] = updated
        refreshSummary(for: updated)
        scheduleSave(updated)
    }

    /// Inserts/updates the summary for a conversation and re-sorts the sidebar.
    private func refreshSummary(for conversation: Conversation) {
        let summary = ConversationSummary(conversation)
        var next = summaries.filter { $0.id != conversation.id }
        next.append(summary)
        summaries = next.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Persists a conversation immediately (transcript + optionally the index).
    private func persist(_ conversation: Conversation, reindex: Bool) {
        refreshSummary(for: conversation)
        let snapshot = summaries
        Task {
            await store.save(conversation)
            if reindex {
                await store.saveIndex(snapshot)
            }
        }
    }

    /// Debounces transcript writes so streaming checkpoints in quick succession
    /// coalesce into a single disk write per conversation.
    private func scheduleSave(_ conversation: Conversation) {
        saveTasks[conversation.id]?.cancel()
        let snapshot = summaries
        saveTasks[conversation.id] = Task { [weak self] in
            try? await Task.sleep(for: ConversationManager.saveDebounce)
            guard !Task.isCancelled, let self else { return }
            await self.store.save(conversation)
            await self.store.saveIndex(snapshot)
            self.saveTasks.removeValue(forKey: conversation.id)
        }
    }
}
