//
//  TextChunker.swift
//  Local402
//
//  Splits page text into overlapping word-windows. Chunks never cross page
//  boundaries, so each chunk keeps an accurate source page for citations.
//

import Foundation

struct TextChunk: Sendable {
    let index: Int     // global chunk index within the document
    let text: String
    let page: Int      // 1-based source page
}

nonisolated enum TextChunker {
    /// - Parameters:
    ///   - wordsPerChunk: target window size; ~180 words sits comfortably inside
    ///     the sentence-embedding model's effective context.
    ///   - overlapWords: words shared between adjacent chunks to preserve context
    ///     that would otherwise be split across a boundary.
    static func chunk(pages: [String], wordsPerChunk: Int = 180, overlapWords: Int = 40) -> [TextChunk] {
        precondition(wordsPerChunk > overlapWords, "overlap must be smaller than the window")
        var chunks: [TextChunk] = []
        var index = 0
        let step = wordsPerChunk - overlapWords

        for (pageIdx, raw) in pages.enumerated() {
            let words = normalize(raw)
            guard !words.isEmpty else { continue }

            var start = 0
            while start < words.count {
                let end = min(start + wordsPerChunk, words.count)
                let piece = words[start..<end].joined(separator: " ")
                if !piece.isEmpty {
                    chunks.append(TextChunk(index: index, text: piece, page: pageIdx + 1))
                    index += 1
                }
                if end == words.count { break }
                start += step
            }
        }
        return chunks
    }

    /// Collapse all whitespace runs, strip soft hyphens, and tokenize on spaces.
    private static func normalize(_ s: String) -> [String] {
        s.replacingOccurrences(of: "\u{00AD}", with: "")     // soft hyphen
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
