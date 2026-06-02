//
//  RAGStore.swift
//  Local402
//
//  Main-actor bridge between SwiftUI and the RAGEngine actor. Owns all state for
//  the RAG terminal. Follows the app's @Observable store pattern (cf. WalletStore).
//

import Foundation
import Observation

/// Which surface the right pane of the RAG terminal is showing.
enum RAGPaneMode: String, CaseIterable, Identifiable, Sendable {
    case retrieve = "Retrieve"
    case inspect = "Inspect"
    var id: String { rawValue }
}

@Observable
@MainActor
final class RAGStore {
    // Store contents + stats
    private(set) var documents: [DocumentMeta] = []
    private(set) var totalChunks = 0
    private(set) var embeddingDimension = 0
    private(set) var databasePath = ""
    private(set) var databaseSizeBytes = 0
    private(set) var isReady = false

    // Retrieve
    var query = ""
    private(set) var results: [SearchResult] = []
    private(set) var hasSearched = false

    // Inspect
    var mode: RAGPaneMode = .retrieve
    private(set) var selectedDocumentID: String?
    private(set) var inspectedChunks: [StoredChunk] = []

    // Transient activity
    private(set) var isIngesting = false
    private(set) var isSearching = false
    private(set) var isInspecting = false
    private(set) var ingestProgress = 0.0
    private(set) var statusMessage = "Starting up…"
    var errorMessage: String?

    private var engine: RAGEngine?

    var selectedDocument: DocumentMeta? {
        documents.first { $0.id == selectedDocumentID }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard engine == nil else { return }
        do {
            // Build the engine off the main thread — loading the embedding model
            // and opening SQLite shouldn't block the UI.
            let engine = try await Task.detached(priority: .userInitiated) {
                try RAGEngine()
            }.value
            self.engine = engine
            self.embeddingDimension = engine.embeddingDimension
            self.databasePath = engine.databasePath
            self.isReady = true
            await refresh()
            statusMessage = documents.isEmpty
                ? "Ready — add a PDF to populate the vector store."
                : "Loaded \(documents.count) document(s)."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to start the RAG engine."
        }
    }

    private func refresh() async {
        guard let engine else { return }
        do {
            documents = try await engine.documents()
            totalChunks = try await engine.totalChunks()
            recomputeDatabaseSize()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Ingest

    func addPDFs(_ urls: [URL]) {
        guard let engine, !urls.isEmpty else { return }
        Task {
            isIngesting = true
            ingestProgress = 0
            defer { isIngesting = false; ingestProgress = 0 }

            var lastAddedID: String?
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let meta = try await engine.ingestPDF(at: url) { progress in
                        Task { @MainActor in
                            self.ingestProgress = progress.fraction
                            self.statusMessage = progress.message
                        }
                    }
                    lastAddedID = meta.id
                    statusMessage = "Added “\(meta.filename)” — \(meta.chunkCount) chunks embedded."
                } catch {
                    errorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
            await refresh()

            // After upload, surface the freshly built vectors: select the new
            // document and switch to the inspector so its chunks are visible.
            if let id = lastAddedID, let doc = documents.first(where: { $0.id == id }) {
                await loadChunks(for: doc)
                mode = .inspect
            }
        }
    }

    func delete(_ doc: DocumentMeta) {
        guard let engine else { return }
        Task {
            do {
                try await engine.deleteDocument(id: doc.id)
                statusMessage = "Removed “\(doc.filename)”."
                results.removeAll { $0.documentId == doc.id }
                if selectedDocumentID == doc.id {
                    selectedDocumentID = nil
                    inspectedChunks = []
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh()
        }
    }

    func clearAll() {
        guard let engine else { return }
        Task {
            do {
                try await engine.reset()
                results = []
                hasSearched = false
                selectedDocumentID = nil
                inspectedChunks = []
                statusMessage = "Cleared the vector store."
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh()
        }
    }

    // MARK: - Search

    func runSearch() {
        guard let engine else { return }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        Task {
            isSearching = true
            mode = .retrieve
            defer { isSearching = false }
            do {
                results = try await engine.search(q, topK: 8)
                hasSearched = true
                statusMessage = results.isEmpty
                    ? "No matches for “\(q)”."
                    : "Top \(results.count) match(es) for “\(q)”."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Inspect

    func select(_ doc: DocumentMeta) {
        Task {
            await loadChunks(for: doc)
            mode = .inspect
        }
    }

    private func loadChunks(for doc: DocumentMeta) async {
        guard let engine else { return }
        isInspecting = true
        selectedDocumentID = doc.id
        defer { isInspecting = false }
        do {
            inspectedChunks = try await engine.chunks(forDocument: doc.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    /// Sum the SQLite database plus its WAL/SHM sidecar files.
    private func recomputeDatabaseSize() {
        guard !databasePath.isEmpty else { databaseSizeBytes = 0; return }
        let fm = FileManager.default
        let total = [databasePath, databasePath + "-wal", databasePath + "-shm"].reduce(0) { sum, path in
            let size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            return sum + (size ?? 0)
        }
        databaseSizeBytes = total
    }

    var databaseSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(databaseSizeBytes), countStyle: .file)
    }
}
