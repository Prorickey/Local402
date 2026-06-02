//
//  LLMEngine.swift
//  Local402
//
//  The on-device LLM. Wraps mlx-swift-lm: downloads/loads an MLX model from the
//  Hugging Face hub and runs a `ChatSession` that streams tokens and dispatches
//  tool calls. An `actor` because `ChatSession` is single-threaded — the actor
//  serializes access while letting the rest of the app stay on the main thread.
//
//  Retrieval is a TOOL (`search_documents`): the model decides when to query the
//  local RAG store. When it does, the hits are reported to the UI as citations.
//
//  Integration follows mlx-swift-lm "Method 2": the `#huggingFaceLoadModelContainer`
//  macro adapts swift-huggingface's `HubClient` (download) and swift-transformers'
//  `AutoTokenizer` (chat template + tool formatting) to MLXLMCommon's protocols.
//

import Foundation
import os
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
// Referenced by the macro expansion below — required even though unused directly.
import HuggingFace
import Tokenizers

enum LLMError: LocalizedError {
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .notLoaded: return "The local model isn't loaded yet."
        }
    }
}

actor LLMEngine {
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "LLMEngine")
    private let tools: [AnyTool]

    private var container: ModelContainer?
    private var session: ChatSession?
    private(set) var loadedModelID: String?

    /// Retrieval backend for the `search_documents` tool (wired to the RAG store).
    private var ragRetrieve: (@Sendable (String, Int) async -> [SearchResult])?
    /// Sink for citations produced during the current reply (set per `reply`).
    private var citationSink: (@Sendable ([Citation]) -> Void)?

    init(tools: [AnyTool] = AgentTools.default) {
        self.tools = tools
    }

    var isLoaded: Bool { session != nil }

    /// Connect the on-device document store so the model's `search_documents`
    /// tool can query it. `retrieve(query, topK)` returns the best matches.
    func connectRAG(_ retrieve: @escaping @Sendable (String, Int) async -> [SearchResult]) {
        self.ragRetrieve = retrieve
    }

    // MARK: - Loading

    /// Downloads (if needed) and loads the model, then builds a tool-enabled
    /// `ChatSession`. Idempotent for an already-loaded model id.
    /// `progress` reports download fraction (0...1) and a status message.
    func load(
        modelID: String,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        if loadedModelID == modelID, session != nil { return }

        progress(0, "Preparing \(modelID)…")
        let configuration = ModelConfiguration(id: modelID)

        // The macro expands to `loadModelContainer(from: HubClient()…, using: AutoTokenizer…)`.
        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: { p in
                progress(p.fractionCompleted, "Downloading model… \(Int(p.fractionCompleted * 100))%")
            }
        )
        progress(1, "Loading into memory…")

        self.container = container
        self.loadedModelID = modelID
        self.session = makeSession(for: container)
        logger.info("Loaded model \(modelID, privacy: .public)")
    }

    private func makeSession(for container: ModelContainer) -> ChatSession {
        // search_documents (handled here) + any self-contained tools (web_search).
        let toolSpecs = [AgentTools.documentSearchSchema] + tools.map(\.schema)

        let dispatch: @Sendable (ToolCall) async throws -> String = { [weak self] call in
            guard let self else { return #"{"error":"engine released"}"# }
            return try await self.dispatchTool(call)
        }

        return ChatSession(
            container,
            instructions: Self.systemPrompt,
            generateParameters: GenerateParameters(temperature: 0.6),
            tools: toolSpecs,
            toolDispatch: dispatch
        )
    }

    // MARK: - Tool dispatch

    private func dispatchTool(_ call: ToolCall) async throws -> String {
        if call.function.name == AgentTools.documentSearchName {
            return await handleDocumentSearch(call)
        }
        if let tool = tools.first(where: { $0.name == call.function.name }) {
            return try await tool.dispatch(call)
        }
        return #"{"error":"unknown tool: \#(call.function.name)"}"#
    }

    /// Runs a RAG query, reports the hits to the UI as citations, and returns the
    /// passages as text for the model to read.
    private func handleDocumentSearch(_ call: ToolCall) async -> String {
        let query = Self.stringArgument(call, "query")
        let hits = await ragRetrieve?(query, 5) ?? []
        if !hits.isEmpty {
            let citations = hits.map {
                Citation(id: $0.id, documentName: $0.documentName, page: $0.page, snippet: $0.text)
            }
            citationSink?(citations)
        }
        logger.info("search_documents → \(hits.count, privacy: .public) hit(s)")
        return Self.formatDocumentResults(hits)
    }

    // MARK: - Inference

    /// Streams the assistant's reply token-by-token. The model may call
    /// `search_documents` (reported via `onCitations`) or `web_search` mid-reply;
    /// `ChatSession` handles the tool loop transparently inside the stream.
    func reply(
        userText: String,
        onCitations: @escaping @Sendable ([Citation]) -> Void
    ) -> AsyncThrowingStream<String, Error> {
        citationSink = onCitations
        guard let session else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.notLoaded) }
        }
        return session.streamResponse(to: userText)
    }

    /// Clears multi-turn history (keeps the system instructions and loaded weights).
    func resetConversation() async {
        await session?.clear()
    }

    // MARK: - Helpers

    private static func stringArgument(_ call: ToolCall, _ key: String) -> String {
        if case .string(let value)? = call.function.arguments[key] { return value }
        return ""
    }

    private static func formatDocumentResults(_ hits: [SearchResult]) -> String {
        guard !hits.isEmpty else {
            return #"{"results":[],"note":"no matching passages found in the local documents"}"#
        }
        return hits.enumerated().map { index, hit in
            "[\(index + 1)] \(hit.documentName) (p.\(hit.page)):\n\(hit.text)"
        }.joined(separator: "\n\n")
    }

    private static let systemPrompt = """
        You are Local402, a privacy-first assistant running entirely on the user's \
        Mac. You have two tools:
        • search_documents — searches the user's private local documents. Free and \
        on-device. Use it FIRST whenever a question might be answered by the user's \
        own files.
        • web_search — reaches the public internet for a small fee. Use it only when \
        the local documents can't answer a question that needs current external info.
        Prefer the user's documents. Be concise, and cite which document a fact came \
        from when you used search_documents.
        """
}
