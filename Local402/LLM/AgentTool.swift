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

    /// Name the model emits to search the public web. Like `search_documents`,
    /// dispatch is handled specially inside `LLMEngine`: the call runs a REAL
    /// Tavily search settled over x402 (via `CoinbaseServicing`) and reports the
    /// resulting micropayment back to the UI, so only the schema lives here.
    static let webSearchName = "web_search"

    static let webSearchSchema: ToolSpec = Tool<QueryArg, String>(
        name: webSearchName,
        description: """
            Search the public web for current information that is NOT present in \
            the user's local documents. This is a billed tool: each call costs a \
            small fee (USDC) settled over x402. Only call it when local context is \
            insufficient and fresh external data is genuinely needed.
            """,
        parameters: [
            .required("query", type: .string, description: "The search query")
        ]
    ) { _ in "" }.schema

    /// Self-contained tools handed to every chat session. The two built-ins
    /// (`search_documents`, `web_search`) are engine-handled — they need the RAG
    /// store and the Coinbase service and report citations/payments to the UI —
    /// so they are NOT listed here; this seam is for future stateless tools.
    static let `default`: [AnyTool] = []
}
