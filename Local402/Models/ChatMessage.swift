//
//  ChatMessage.swift
//  Local402
//
//  A chat message composed of ordered segments (text + inline payments).
//

import Foundation

enum ChatRole: Hashable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: ChatRole
    var segments: [MessageSegment]
    let timestamp: Date
    var isStreaming: Bool
    /// Local-document sources the model retrieved while answering, if any.
    var citations: [Citation]

    init(
        id: UUID = UUID(),
        role: ChatRole,
        segments: [MessageSegment],
        timestamp: Date,
        isStreaming: Bool = false,
        citations: [Citation] = []
    ) {
        self.id = id
        self.role = role
        self.segments = segments
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.citations = citations
    }

    /// Convenience for a plain-text message.
    static func text(_ value: String, role: ChatRole, timestamp: Date, isStreaming: Bool = false) -> ChatMessage {
        ChatMessage(role: role, segments: [.text(value)], timestamp: timestamp, isStreaming: isStreaming)
    }
}
