//
//  LLMStore.swift
//  Local402
//
//  Main-actor bridge between SwiftUI and the `LLMEngine` actor — mirrors the
//  RAGStore pattern. Owns the load lifecycle (download → load → ready) so views
//  can show progress, and forwards streaming replies to ChatStore.
//

import Foundation
import Observation

@Observable
@MainActor
final class LLMStore {
    enum Phase: Equatable {
        case idle
        case downloading(Double)   // 0...1
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    /// Hugging Face repo id of the model to load (set from the onboarding choice).
    var modelID: String
    /// Display name for the header/greeting.
    var modelName: String

    private let engine = LLMEngine()
    private var loadTask: Task<Void, Error>?
    private var ragRetrieve: (@Sendable (String, Int) async -> [SearchResult])?

    init(modelID: String = MockModels.default.id, modelName: String = MockModels.default.name) {
        self.modelID = modelID
        self.modelName = modelName
    }

    /// Wire the on-device document store into the model's `search_documents`
    /// tool. Applied to the engine when the model loads.
    func connectRAG(_ retrieve: @escaping @Sendable (String, Int) async -> [SearchResult]) {
        self.ragRetrieve = retrieve
    }

    var isReady: Bool { phase == .ready }

    var statusLabel: String {
        switch phase {
        case .idle: return "Model not loaded"
        case .downloading(let f): return "Downloading \(modelName)… \(Int(f * 100))%"
        case .loading: return "Loading \(modelName)…"
        case .ready: return "\(modelName) ready"
        case .failed(let message): return "Load failed: \(message)"
        }
    }

    /// Loads the model if needed. Safe to call repeatedly and from many callers —
    /// concurrent callers await the same in-flight load. Throws on failure.
    func ensureReady() async throws {
        if phase == .ready { return }
        if let loadTask {
            try await loadTask.value
            return
        }
        let task = Task { try await runLoad() }
        loadTask = task
        do {
            try await task.value
        } catch {
            loadTask = nil   // allow a retry on the next send
            throw error
        }
    }

    private func runLoad() async throws {
        phase = .downloading(0)
        do {
            if let ragRetrieve { await engine.connectRAG(ragRetrieve) }
            try await engine.load(modelID: modelID) { [weak self] fraction, _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isReady else { return }
                    self.phase = fraction < 1 ? .downloading(fraction) : .loading
                }
            }
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
            throw error
        }
    }

    /// Streams the assistant's reply. The model decides whether to query local
    /// documents; any retrieved sources are reported via `onCitations`.
    func reply(
        userText: String,
        onCitations: @escaping @Sendable ([Citation]) -> Void
    ) async -> AsyncThrowingStream<String, Error> {
        await engine.reply(userText: userText, onCitations: onCitations)
    }

    /// Forget conversation history (e.g. when onboarding restarts).
    func resetConversation() async {
        await engine.resetConversation()
    }
}
