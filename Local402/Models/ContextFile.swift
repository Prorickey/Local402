//
//  ContextFile.swift
//  Local402
//
//  A company data file added to the agent's context (filler data).
//

import Foundation

struct ContextFile: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let sizeBytes: Int

    init(id: UUID = UUID(), fileName: String, sizeBytes: Int) {
        self.id = id
        self.fileName = fileName
        self.sizeBytes = sizeBytes
    }

    /// File extension used to pick an SF Symbol and a type label.
    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    var typeLabel: String {
        fileExtension.isEmpty ? "FILE" : fileExtension.uppercased()
    }

    var systemImage: String {
        switch fileExtension {
        case "pdf": return "doc.richtext"
        case "xlsx", "csv", "numbers": return "tablecells"
        case "sql", "db": return "cylinder"
        case "md", "txt", "rtf": return "doc.text"
        case "json", "yaml", "yml": return "curlybraces"
        case "png", "jpg", "jpeg", "gif": return "photo"
        case "zip", "tar", "gz": return "archivebox"
        default: return "doc"
        }
    }

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}
