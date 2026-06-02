//
//  RAGTypes.swift
//  Local402
//
//  Core value types for the on-device RAG pipeline. All Sendable so they can
//  cross the RAGEngine actor boundary back to the main-actor store.
//

import Foundation

/// Metadata for one ingested document (one PDF = one document).
struct DocumentMeta: Identifiable, Hashable, Sendable {
    let id: String
    let filename: String
    let pageCount: Int
    let chunkCount: Int
    let addedAt: Date
}

/// A single retrieval hit returned from a search.
struct SearchResult: Identifiable, Hashable, Sendable {
    let id: String            // chunk id
    let documentId: String
    let documentName: String
    let chunkIndex: Int
    let page: Int
    let text: String
    let score: Double          // cosine similarity in [-1, 1]
}

/// A chunk as it actually lives in the vector store, including its embedding.
struct StoredChunk: Identifiable, Hashable, Sendable {
    let id: String
    let chunkIndex: Int
    let page: Int
    let text: String
    let embedding: [Float]
}

/// Progress signal emitted during ingestion so the UI can show live status.
struct IngestProgress: Sendable {
    let fraction: Double       // 0...1
    let message: String
}

enum RAGError: LocalizedError {
    case couldNotOpenPDF(String)
    case noTextExtracted
    case embeddingUnavailable
    case embeddingFailed(String)
    case sqlite(String)

    var errorDescription: String? {
        switch self {
        case .couldNotOpenPDF(let name):
            return "Couldn't open \"\(name)\". It may not be a valid PDF."
        case .noTextExtracted:
            return "No selectable text found — this PDF looks like scanned images (OCR isn't wired up yet)."
        case .embeddingUnavailable:
            return "The on-device sentence-embedding model is unavailable on this system."
        case .embeddingFailed(let s):
            return "Embedding failed: \(s)"
        case .sqlite(let s):
            return "Vector store error: \(s)"
        }
    }
}
