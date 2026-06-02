# Local402

> A fully local, privacy-first desktop research application built in Swift. Your documents never leave your machine. Your reasoning never leaves your machine. Only your deliberate, paid search queries do.

---

## What It Is

Local402 is a native macOS desktop app that combines three things into a single interface:

1. **A local LLM** — an open-weights model (Qwen2.5 / Llama 3.2) running entirely on your Apple Silicon hardware via **MLX**, streaming tokens in real time
2. **Private RAG document store** — drop in PDFs that are chunked, embedded, and queried locally, then fed to the model as grounding context
3. **x402-gated tools** — when the model needs live web data, it calls a paid tool that settles over Coinbase's x402 micropayment rail *(payment settlement is the next milestone; the tool-calling seam is already wired)*

No data leaves your machine unless you authorize it — and when it does, you pay exactly once for exactly what you asked for.

---

## Why Local

The local model is the privacy boundary. When you feed private documents (contracts, financials, medical records, internal reports) into a hosted LLM, your full context window — including every document, every reasoning step — leaves your machine before any search is even formed.

With Local402, the model processes everything on-device on Apple Silicon's GPU via MLX. The only signal that ever leaves is a final search query, deliberately sent by the model as a tool call, with a micropayment attached.

**Privacy surface comparison:**

| | Hosted LLM + Search | Local402 |
|---|---|---|
| Your documents | Sent to provider | Stay on device |
| Reasoning chain | Sent to provider | Stays on device |
| Search queries | Sent to provider + search API | Sent to a search API only, via x402 |
| Provider data logging | Per their ToS | None |
| Variable cost | Tokens + search | Search only |

---

## Core Features

### RAG Document Store
- Drop in PDFs; text is extracted, chunked, and embedded locally
- Embeddings use Apple's on-device `NaturalLanguage` model — no cloud embedding service
- Vectors live in a local SQLite store with cosine-similarity search
- The model retrieves the top matches and grounds its answer in them before considering any paid tool

### On-Device Chat
- Tokens stream live as the model generates them
- Replies are grounded in retrieved document context and cite which document a fact came from
- Pick your model during onboarding — from a fast ~1 GB model up to sharper 3 B variants

### Tool Calling → x402 Payments
- The model can call tools mid-reply; `web_search` is registered as a *billed* tool
- mlx-swift-lm's `ChatSession` drives the streaming tool-call loop natively — detect, dispatch, feed the result back, resume
- The dispatch handler is the single seam where Tavily + x402 settlement plugs in *(currently stubbed)*

### x402 Coinbase Wallet *(UI simulated today)*
- Connect a Coinbase smart wallet in the UI — no terminal, no `.env`, no CLI
- Wallet balance, spend history, and per-query cost visible at a glance

---

## Core Loop — Agentic Research

1. User submits a query
2. The on-device model loads (first run downloads the weights from Hugging Face)
3. Local RAG retrieves the most relevant document chunks
4. The model answers from local context — free and private — or decides it needs the web
5. If so, it emits a `web_search` tool call; the handler settles an x402 payment and returns results *(next milestone)*
6. The final answer is grounded in both private and public sources, with citations

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5 / Swift Concurrency |
| Desktop framework | SwiftUI (macOS native) |
| Local inference | MLX via [`mlx-swift-lm`](https://github.com/ml-explore/mlx-swift-lm) |
| Models | `mlx-community` 4-bit: Qwen2.5 1.5B/3B, Llama 3.2 1B/3B |
| Tokenizer / chat templates | `swift-transformers` + `swift-jinja` |
| Model download | `swift-huggingface` (Hugging Face Hub) |
| Local embeddings | Apple `NaturalLanguage` (`NLEmbedding`) |
| Vector store | SQLite-backed local vector index (cosine similarity) |
| Tool calling | Native function calling via `ChatSession` |
| Payment rail | x402 + Coinbase AgentKit *(in progress)* |
| Web search | Tavily API *(in progress)* |

---

## Architecture

The integration seam is small and deliberate:

- **`LLM/LLMEngine.swift`** — an `actor` that downloads/loads an MLX model and runs a tool-enabled `ChatSession`, exposing replies as an `AsyncThrowingStream<String, Error>`.
- **`LLM/AgentTool.swift`** — the tool registry. `web_search` is defined here; this is where paid tools land.
- **`State/LLMStore.swift`** — `@MainActor` bridge owning the download → load → ready lifecycle for the UI.
- **`RAG/RAGEngine.swift`** — an `actor` running extract → chunk → embed → store → search.
- **`State/ChatStore.swift`** — ties them together: retrieve context, stream the reply, dispatch tools.

---

## Why Swift

- **Apple Silicon performance** — MLX runs the model on the GPU via Metal, extracting maximum performance from M-series chips
- **Native privacy APIs** — macOS sandboxing, entitlements, and the Secure Enclave are first-class
- **No runtime dependencies** — ships as a self-contained binary; no Python, Node, or Docker for the user to manage
- **SwiftUI** — declarative UI that keeps the documents / chat / wallet layout clean

---

## Privacy Model

Local402 operates on a **minimal disclosure principle**:

- **Documents** — chunked, embedded, and stored in a local SQLite vector index. Never transmitted.
- **Reasoning** — the model's full generation runs in device memory via MLX. Never transmitted.
- **Queries** — only a final, deliberate search string leaves the machine, as a tool call paid via x402.
- **Wallet** — managed client-side via Coinbase Smart Wallet. No private keys handled by the app.

Suitable for use cases where data residency matters: legal research, financial analysis, healthcare, and internal business intelligence.

---

## Requirements

- macOS 14 (Sonoma) or later
- **Apple Silicon (M1 or later)** — required; MLX inference uses the Metal GPU
- ~1–2 GB free disk for the model weights (downloaded once, on first chat)
- Coinbase Smart Wallet account for x402 payments *(when that milestone lands)*

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/your-org/local402

# Open in Xcode (Swift packages resolve automatically)
open Local402.xcodeproj
```

On first launch:
1. Pick a local model — it downloads from Hugging Face on first use
2. Drop in PDFs to populate the local vector store
3. Start chatting; the model grounds its answers in your documents

---

## Roadmap

- [ ] Wire `web_search` to Tavily and settle the call over x402
- [ ] Surface model download/load progress in the chat UI
- [ ] Multi-document citation with source highlighting in SwiftUI
- [ ] Spend-limit controls per session
- [ ] Export research sessions as PDF reports
- [ ] Team mode — shared local document store over LAN

---

## License

MIT
