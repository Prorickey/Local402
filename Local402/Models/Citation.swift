//
//  Citation.swift
//  Local402
//
//  A reference to a local document passage the model retrieved via the
//  `search_documents` tool. Shown as a small source chip under the reply.
//

import Foundation

struct Citation: Identifiable, Hashable, Sendable, Codable {
    let id: String          // the source chunk id
    let documentName: String
    let page: Int
    let snippet: String

    /// Compact label for the source chip, e.g. "handbook.pdf · p.3".
    var label: String { "\(documentName) · p.\(page)" }
}
