//
//  Conversation.swift
//  Local402
//
//  A persisted chat conversation: its identity, derived title, the model it runs
//  on, timestamps, and the full ordered transcript. Value type with immutable
//  update helpers — callers produce new copies rather than mutating in place.
//

import Foundation

struct Conversation: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let modelName: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String,
        modelName: String,
        createdAt: Date,
        updatedAt: Date,
        messages: [ChatMessage]
    ) {
        self.id = id
        self.title = title
        self.modelName = modelName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    /// Placeholder title shown until the first user message arrives.
    static let untitled = "New chat"

    /// Returns a copy with refreshed messages, a title derived from the first
    /// user message, and a bumped `updatedAt`.
    func updating(messages: [ChatMessage], now: Date = Date()) -> Conversation {
        Conversation(
            id: id,
            title: Conversation.derivedTitle(from: messages, fallback: title),
            modelName: modelName,
            createdAt: createdAt,
            updatedAt: now,
            messages: messages
        )
    }

    /// Derives a title from the first user message's text (truncated ~40 chars).
    /// Falls back to the provided value (or "New chat") when no user text exists.
    static func derivedTitle(from messages: [ChatMessage], fallback: String = untitled) -> String {
        guard let firstUserText = firstUserText(in: messages) else {
            return fallback
        }
        return truncatedTitle(firstUserText)
    }

    private static func firstUserText(in messages: [ChatMessage]) -> String? {
        for message in messages where message.role == .user {
            for segment in message.segments {
                if case .text(let value) = segment {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    private static func truncatedTitle(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 40 else { return collapsed }
        return String(collapsed.prefix(40)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
