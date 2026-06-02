//
//  AgentTool.swift
//  Local402
//
//  The tool-calling seam. mlx-swift-lm's `ChatSession` drives the streaming
//  tool-call loop for us: we hand it a list of JSON tool schemas plus a single
//  `toolDispatch` closure, and it pauses generation, calls the tool, feeds the
//  result back, and resumes — all inside one `streamResponse`.
//
//  `AnyTool` type-erases mlx-swift-lm's generic `Tool<Input, Output>` down to a
//  name + schema + `(ToolCall) -> String` dispatcher so the engine can hold a
//  heterogeneous registry. This is exactly where the x402-paid tools (Tavily
//  web search, market data, etc.) plug in once the payment system is merged.
//

import Foundation
import MLXLMCommon

/// A tool the model can call, erased to a uniform shape the engine can store.
struct AnyTool: Sendable {
    let name: String
    /// JSON Schema describing the function, as mlx-swift-lm expects.
    let schema: ToolSpec
    /// Executes the call and returns a string result fed back to the model.
    let dispatch: @Sendable (ToolCall) async throws -> String
}

extension Tool where Output == String {
    /// Erase a typed `Tool` whose handler already returns a string result.
    func erased() -> AnyTool {
        AnyTool(name: name, schema: schema) { call in
            try await call.execute(with: self)
        }
    }
}

// MARK: - Built-in tools

/// Typed arguments used only to generate the tools' JSON schemas.
private struct QueryArg: Codable {
    let query: String
}

enum AgentTools {
    /// Name the model emits to search the user's local documents. Dispatch is
    /// handled specially inside `LLMEngine` (it needs the RAG engine and reports
    /// citations back to the UI), so only the schema lives here.
    static let documentSearchName = "search_documents"

    static let documentSearchSchema: ToolSpec = Tool<QueryArg, String>(
        name: documentSearchName,
        description: """
            Search the user's PRIVATE local documents (their uploaded PDFs) for \
            passages relevant to the question. Free and fully on-device. Use this \
            FIRST for anything that might be answered by the user's own files; only \
            fall back to web_search if the documents don't contain the answer.
            """,
        parameters: [
            .required("query", type: .string, description: "What to look up in the local documents")
        ]
    ) { _ in "" }.schema
    /// Web search — a *paid* tool in Local402's model. For now it is a stub that
    /// returns no results; when the payment system lands, this handler will call
    /// Tavily and settle the charge over x402 before returning real hits. Keeping
    /// it registered means the model already knows the capability exists and the
    /// merge is a one-function change.
    static let webSearch: AnyTool = Tool<QueryArg, String>(
        name: "web_search",
        description: """
            Search the public web for current information that is NOT present in \
            the user's local documents. This is a billed tool: each call costs a \
            small fee settled over x402. Only call it when local context is \
            insufficient and fresh external data is genuinely needed.
            """,
        parameters: [
            .required("query", type: .string, description: "The search query")
        ]
    ) { args in
        // STUB pending payment integration. Returns an empty, well-formed result
        // so the model can gracefully continue ("I couldn't find external info").
        let payload: [String: Any] = [
            "status": "unavailable",
            "reason": "web_search is stubbed until x402 payments are wired up",
            "query": args.query,
            "results": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(decoding: data, as: UTF8.self)
    }.erased()

    /// The default tool set handed to every chat session.
    static let `default`: [AnyTool] = [webSearch]
}
