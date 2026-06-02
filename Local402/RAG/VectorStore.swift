//
//  VectorStore.swift
//  Local402
//
//  SQLite-backed store for documents and their embedded chunks. Embeddings are
//  persisted as raw Float BLOBs; search is brute-force cosine similarity over
//  all chunks — exact and plenty fast for thousands of chunks. (Swap the scan
//  for sqlite-vec if the corpus ever grows large.)
//
//  `nonisolated` + owned exclusively by the RAGEngine actor, which serializes
//  every call, so the raw connection pointer is never shared across threads.
//

import Foundation
import SQLite3

// SQLite wants to know whether it can keep a pointer or must copy it.
// TRANSIENT == "copy now", the safe choice for Swift-owned buffers.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

nonisolated final class VectorStore {
    private var db: OpaquePointer?

    init(url: URL) throws {
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            defer { sqlite3_close(db) }
            throw RAGError.sqlite(lastErrorMessage)
        }
        try exec("PRAGMA journal_mode = WAL;")
        try exec("PRAGMA foreign_keys = ON;")
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Schema

    private func migrate() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS documents (
                id          TEXT PRIMARY KEY,
                filename    TEXT NOT NULL,
                page_count  INTEGER NOT NULL,
                chunk_count INTEGER NOT NULL,
                added_at    REAL NOT NULL
            );
            """)
        try exec("""
            CREATE TABLE IF NOT EXISTS chunks (
                id          TEXT PRIMARY KEY,
                document_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                page        INTEGER NOT NULL,
                text        TEXT NOT NULL,
                embedding   BLOB NOT NULL,
                dim         INTEGER NOT NULL,
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
            );
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(document_id);")
    }

    // MARK: - Writes

    /// Insert a document and all of its embedded chunks in a single transaction.
    func insertDocument(_ meta: DocumentMeta, chunks: [(TextChunk, [Float])], dim: Int) throws {
        try exec("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let docSQL = "INSERT INTO documents (id, filename, page_count, chunk_count, added_at) VALUES (?,?,?,?,?);"
            try withStatement(docSQL) { stmt in
                sqlite3_bind_text(stmt, 1, meta.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, meta.filename, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 3, Int32(meta.pageCount))
                sqlite3_bind_int(stmt, 4, Int32(meta.chunkCount))
                sqlite3_bind_double(stmt, 5, meta.addedAt.timeIntervalSince1970)
                try step(stmt)
            }

            let chunkSQL = """
                INSERT INTO chunks (id, document_id, chunk_index, page, text, embedding, dim)
                VALUES (?,?,?,?,?,?,?);
                """
            try withStatement(chunkSQL) { stmt in
                for (chunk, vector) in chunks {
                    let blob = vector.withUnsafeBytes { Data($0) }
                    sqlite3_bind_text(stmt, 1, UUID().uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 2, meta.id, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(stmt, 3, Int32(chunk.index))
                    sqlite3_bind_int(stmt, 4, Int32(chunk.page))
                    sqlite3_bind_text(stmt, 5, chunk.text, -1, SQLITE_TRANSIENT)
                    _ = blob.withUnsafeBytes { raw in
                        sqlite3_bind_blob(stmt, 6, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
                    }
                    sqlite3_bind_int(stmt, 7, Int32(dim))
                    try step(stmt)
                    sqlite3_reset(stmt)
                    sqlite3_clear_bindings(stmt)
                }
            }
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    func deleteDocument(id: String) throws {
        try withStatement("DELETE FROM documents WHERE id = ?;") { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            try step(stmt)
        }
    }

    func reset() throws {
        try exec("DELETE FROM chunks;")
        try exec("DELETE FROM documents;")
    }

    // MARK: - Reads

    func allDocuments() throws -> [DocumentMeta] {
        var results: [DocumentMeta] = []
        try withStatement("""
            SELECT id, filename, page_count, chunk_count, added_at
            FROM documents ORDER BY added_at DESC;
            """) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(DocumentMeta(
                    id: column(stmt, 0),
                    filename: column(stmt, 1),
                    pageCount: Int(sqlite3_column_int(stmt, 2)),
                    chunkCount: Int(sqlite3_column_int(stmt, 3)),
                    addedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                ))
            }
        }
        return results
    }

    /// Every chunk for one document, embeddings included, in reading order.
    func chunks(forDocument id: String) throws -> [StoredChunk] {
        var rows: [StoredChunk] = []
        try withStatement("""
            SELECT id, chunk_index, page, text, embedding
            FROM chunks WHERE document_id = ? ORDER BY chunk_index;
            """) { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let vector: [Float]
                if let blob = sqlite3_column_blob(stmt, 4) {
                    vector = Self.floats(from: blob, byteCount: Int(sqlite3_column_bytes(stmt, 4)))
                } else {
                    vector = []
                }
                rows.append(StoredChunk(
                    id: column(stmt, 0),
                    chunkIndex: Int(sqlite3_column_int(stmt, 1)),
                    page: Int(sqlite3_column_int(stmt, 2)),
                    text: column(stmt, 3),
                    embedding: vector
                ))
            }
        }
        return rows
    }

    func totalChunkCount() throws -> Int {
        var count = 0
        try withStatement("SELECT COUNT(*) FROM chunks;") { stmt in
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        return count
    }

    /// Brute-force nearest-neighbor search by cosine similarity.
    func search(query: [Float], topK: Int) throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        var scored: [SearchResult] = []

        try withStatement("""
            SELECT c.id, c.document_id, c.chunk_index, c.page, c.text, c.embedding, d.filename
            FROM chunks c JOIN documents d ON c.document_id = d.id;
            """) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let blob = sqlite3_column_blob(stmt, 5) else { continue }
                let bytes = Int(sqlite3_column_bytes(stmt, 5))
                let vector = Self.floats(from: blob, byteCount: bytes)
                let score = Self.cosine(query, vector)
                scored.append(SearchResult(
                    id: column(stmt, 0),
                    documentId: column(stmt, 1),
                    documentName: column(stmt, 6),
                    chunkIndex: Int(sqlite3_column_int(stmt, 2)),
                    page: Int(sqlite3_column_int(stmt, 3)),
                    text: column(stmt, 4),
                    score: score
                ))
            }
        }

        return Array(scored.sorted { $0.score > $1.score }.prefix(topK))
    }

    // MARK: - Vector math

    private static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            let x = Double(a[i]), y = Double(b[i])
            dot += x * y; normA += x * x; normB += y * y
        }
        let denom = (normA.squareRoot() * normB.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    private static func floats(from blob: UnsafeRawPointer, byteCount: Int) -> [Float] {
        let count = byteCount / MemoryLayout<Float>.stride
        let buffer = blob.bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: buffer, count: count))
    }

    // MARK: - SQLite helpers

    private var lastErrorMessage: String {
        String(cString: sqlite3_errmsg(db))
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let message = err.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(err)
            throw RAGError.sqlite(message)
        }
    }

    /// Prepare a statement, hand it to `body`, and always finalize it.
    private func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw RAGError.sqlite(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }
        try body(stmt)
    }

    /// Step a write statement and treat anything other than DONE/ROW as an error.
    private func step(_ stmt: OpaquePointer) throws {
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw RAGError.sqlite(lastErrorMessage)
        }
    }

    private func column(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }
}
