//
//  ConversationStore.swift
//  Local402
//
//  Disk-backed persistence for conversations, isolated to its own actor so all
//  file I/O happens off the main actor and is free of data races.
//
//  Layout (under Application Support):
//      <AppSupport>/Local402/conversations/
//          index.json          — ordered [ConversationSummary] for fast sidebar load
//          <uuid>.json         — one full Conversation per file
//
//  Rationale for one-file-per-conversation + an index: the sidebar only needs the
//  summaries to render, so launch never pays to decode every transcript. A single
//  full conversation is loaded lazily on selection, and writes touch only the one
//  changed file (plus the small index) rather than rewriting the whole history.
//
//  Resilience: this layer never throws to the UI. Reads degrade to empty/last-known
//  state and log; writes log on failure. A corrupt individual file is skipped, not
//  fatal — the rest of the history still loads.
//

import Foundation
import os

actor ConversationStore {
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ConversationStore")
    private let fileManager = FileManager.default

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// `<AppSupport>/Local402/conversations`, created on first access. Falls back
    /// to a temp directory if Application Support is somehow unavailable so the
    /// app keeps running (in-session persistence) rather than crashing.
    private lazy var directory: URL = {
        let base: URL
        do {
            base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            logger.error("Application Support unavailable, using temp dir: \(error.localizedDescription, privacy: .public)")
            return fileManager.temporaryDirectory
                .appendingPathComponent("Local402/conversations", isDirectory: true)
        }
        return base
            .appendingPathComponent("Local402", isDirectory: true)
            .appendingPathComponent("conversations", isDirectory: true)
    }()

    private var indexURL: URL { directory.appendingPathComponent("index.json", isDirectory: false) }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    /// Ensures the conversations directory exists. Logs and continues on failure.
    private func ensureDirectory() {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create conversations directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Reads

    /// Loads the ordered conversation summaries from `index.json`. Returns an empty
    /// list (never throws) when no index exists yet or it cannot be read.
    func loadSummaries() -> [ConversationSummary] {
        ensureDirectory()
        guard fileManager.fileExists(atPath: indexURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: indexURL)
            return try decoder.decode([ConversationSummary].self, from: data)
        } catch {
            logger.error("Failed to read index.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Loads a single full conversation by id, or nil if missing/unreadable.
    func loadConversation(id: UUID) -> Conversation? {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Conversation.self, from: data)
        } catch {
            logger.error("Failed to read conversation \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Writes

    /// Persists one conversation's full transcript. Does not touch the index;
    /// callers pair this with `saveIndex` when ordering/title changes.
    func save(_ conversation: Conversation) {
        ensureDirectory()
        do {
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL(for: conversation.id), options: .atomic)
        } catch {
            logger.error("Failed to write conversation \(conversation.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Persists the ordered sidebar index.
    func saveIndex(_ summaries: [ConversationSummary]) {
        ensureDirectory()
        do {
            let data = try encoder.encode(summaries)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            logger.error("Failed to write index.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes a conversation's file. The index is rewritten separately by the caller.
    func delete(id: UUID) {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logger.error("Failed to delete conversation \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
