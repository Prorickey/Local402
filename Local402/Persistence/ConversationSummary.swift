//
//  ConversationSummary.swift
//  Local402
//
//  Lightweight, sidebar-friendly projection of a conversation: just enough to
//  render and order history rows without loading every transcript. Persisted in
//  `index.json` so the sidebar can populate instantly on launch.
//

import Foundation

struct ConversationSummary: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let modelName: String
    let updatedAt: Date

    init(id: UUID, title: String, modelName: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.modelName = modelName
        self.updatedAt = updatedAt
    }

    init(_ conversation: Conversation) {
        self.id = conversation.id
        self.title = conversation.title
        self.modelName = conversation.modelName
        self.updatedAt = conversation.updatedAt
    }
}
