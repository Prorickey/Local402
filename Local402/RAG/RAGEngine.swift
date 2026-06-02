//
//  RAGEngine.swift
//  Local402
//
//  Orchestrates the on-device pipeline: extract → chunk → embed → store → search.
//  An actor so all SQLite + embedding work is serialized off the main thread.
//  This type is the integration seam — the app only ever talks to RAGEngine.
//

import Foundation

actor RAGEngine {
    // Immutable, safe to read without hopping onto the actor.
    nonisolated let embeddingDimension: Int
    nonisolated let databasePath: String

    private let store: VectorStore
    private let embedder: Embedder

    init() throws {
        let dbURL = try Self.databaseDirectory().appendingPathComponent("local_rag.sqlite")
        let store = try VectorStore(url: dbURL)
        guard let embedder = NLEmbedder() else { throw RAGError.embeddingUnavailable }

        self.store = store
        self.embedder = embedder
        self.embeddingDimension = embedder.dimension
        self.databasePath = dbURL.path
    }

    // MARK: - Query

    func documents() throws -> [DocumentMeta] { try store.allDocuments() }
    func totalChunks() throws -> Int { try store.totalChunkCount() }

    func search(_ query: String, topK: Int = 8) throws -> [SearchResult] {
        guard let vector = embedder.embed(query) else { return [] }
        return try store.search(query: vector, topK: topK)
    }

    /// Stored chunks for a document, embeddings included — for the inspector.
    func chunks(forDocument id: String) throws -> [StoredChunk] {
        try store.chunks(forDocument: id)
    }

    // MARK: - Mutate

    func deleteDocument(id: String) throws { try store.deleteDocument(id: id) }
    func reset() throws { try store.reset() }

    /// Full ingest of one PDF. `onProgress` is invoked from the actor's executor;
    /// callers that touch UI should hop to the main actor inside it.
    func ingestPDF(at url: URL, onProgress: @Sendable (IngestProgress) -> Void) throws -> DocumentMeta {
        onProgress(IngestProgress(fraction: 0.03, message: "Reading \(url.lastPathComponent)…"))
        let extraction = try PDFTextExtractor.extract(from: url)

        onProgress(IngestProgress(fraction: 0.10, message: "Splitting into chunks…"))
        let chunks = TextChunker.chunk(pages: extraction.pages)
        guard !chunks.isEmpty else { throw RAGError.noTextExtracted }

        var embedded: [(TextChunk, [Float])] = []
        embedded.reserveCapacity(chunks.count)
        for (i, chunk) in chunks.enumerated() {
            if let vector = embedder.embed(chunk.text) {
                embedded.append((chunk, vector))
            }
            if i % 4 == 0 || i == chunks.count - 1 {
                let frac = 0.10 + 0.82 * Double(i + 1) / Double(chunks.count)
                onProgress(IngestProgress(fraction: frac,
                                          message: "Embedding chunk \(i + 1) of \(chunks.count)…"))
            }
        }
        guard !embedded.isEmpty else { throw RAGError.embeddingFailed("no chunks could be embedded") }

        onProgress(IngestProgress(fraction: 0.95, message: "Writing to vector store…"))
        let meta = DocumentMeta(
            id: UUID().uuidString,
            filename: url.lastPathComponent,
            pageCount: extraction.pageCount,
            chunkCount: embedded.count,
            addedAt: Date()
        )
        try store.insertDocument(meta, chunks: embedded, dim: embeddingDimension)

        onProgress(IngestProgress(fraction: 1.0, message: "Done."))
        return meta
    }

    // MARK: - Storage location

    /// App Support container — always writable inside the sandbox, no entitlement needed.
    private static func databaseDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Local402RAG", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
