# Local402

> A fully local, privacy-first desktop research application built in Swift. Your documents never leave your machine. Your reasoning never leaves your machine. Only your deliberate, paid search queries do.

---

## What It Is

Local402 is a native macOS desktop app that combines three things into a single interface:

1. **Gemma 4 (local)** — Google's on-device model running entirely on your Apple Silicon hardware via Swift
2. **Private RAG document store** — upload PDFs and internal documents that are chunked, embedded, and queried locally
3. **x402-gated Tavily search** — when the model needs live web data, it fires a paid search query over Coinbase's x402 micropayment rail

No data leaves your machine unless you authorize it — and when it does, you pay exactly once for exactly what you asked for.

---

## Why Local

The local model is the privacy boundary. When you feed private documents (contracts, financials, medical records, internal reports) into a hosted LLM, your full context window — including every document, every reasoning step — leaves your machine before any search is even formed.

With Local402, Gemma 4 processes everything on-device using Apple Silicon's Neural Engine. The only signal that ever leaves is the final search query, deliberately sent, with a micropayment attached.

**Privacy surface comparison:**

| | Hosted LLM + Search | Local402 |
|---|---|---|
| Your documents | Sent to provider | Stay on device |
| Reasoning chain | Sent to provider | Stays on device |
| Search queries | Sent to provider + search API | Sent to Tavily only, via x402 |
| Provider data logging | Per their ToS | None |
| Variable cost | Tokens + search | Search only |

---

## Core Features

### Left Panel — RAG Document Store
- Upload PDFs, Word docs, or plain text files
- Documents are chunked and embedded locally using on-device embedding
- Gemma 4 queries your documents before deciding whether to reach out to the web
- All indexing and retrieval happens on-device — nothing is uploaded to a cloud vector store

### Top Right — x402 Coinbase Wallet
- Connect your Coinbase smart wallet directly in the UI — no terminal, no `.env` file, no CLI setup
- Each Tavily search call is gated behind an x402 micropayment
- Wallet balance, spend history, and per-query cost visible at a glance
- Set a spend ceiling per session — the agent will not exceed it

### Core Loop — Agentic Research
1. User submits a research query
2. Gemma 4 checks local RAG documents first
3. If local context is insufficient, the model decides to search the web
4. x402 payment is authorized and sent to Tavily
5. Results are returned and synthesized with local document context
6. Final answer is grounded in both private and public sources, with citations

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| Desktop framework | SwiftUI (macOS native) |
| Local inference | Gemma 4 via MLX Swift / Core ML |
| Local embeddings | On-device via Core ML |
| Vector store | Swift-native local vector index |
| Web search | Tavily API |
| Payment rail | x402 + Coinbase AgentKit |
| Wallet auth | Coinbase Smart Wallet (in-app, no terminal) |
| Networking | Swift Concurrency (async/await) |

---

## Why Swift

Swift is the natural choice for a privacy-first macOS application:

- **Apple Silicon performance** — Gemma 4 runs on the Neural Engine via MLX Swift or Core ML, extracting maximum performance from M-series chips with minimal battery impact
- **Native privacy APIs** — macOS sandboxing, entitlements, and the Secure Enclave are first-class citizens in Swift, not afterthoughts
- **No runtime dependencies** — a Swift app ships as a self-contained binary. No Python environment, no Node runtime, no Docker container for the user to manage
- **SwiftUI** — declarative UI that makes the three-panel layout (documents, chat, wallet) clean to build and easy to maintain

---

## Privacy Model

Local402 operates on a **minimal disclosure principle**:

- **Documents** — chunked, embedded, and stored in a local vector index. Never transmitted.
- **Reasoning** — Gemma 4's chain of thought runs entirely in device memory via MLX. Never transmitted.
- **Queries** — only the final, sanitized search string leaves the machine. Transmitted to Tavily, paid via x402.
- **Wallet** — managed client-side via Coinbase Smart Wallet. No private keys handled by the app.

This makes Local402 suitable for use cases where data residency matters: legal research, financial analysis, healthcare, and internal business intelligence.

---

## Who It's For

- **Enterprises** that need agentic AI over internal documents but cannot use hosted models due to compliance requirements
- **Developers and researchers** who want a self-sovereign AI research loop with no provider dependency
- **Privacy-conscious individuals** who don't want a third-party provider logging what their AI is researching
- **Teams in regulated industries** — legal, finance, healthcare — where data leaving the building is a contractual or regulatory issue

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or later) recommended for Gemma 4 inference performance
- Coinbase Smart Wallet account for x402 payments

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/your-org/local402

# Open in Xcode
open Local402.xcodeproj
```

On first launch:
1. Connect your Coinbase wallet via the top-right wallet button
2. Upload documents using the left panel
3. Start a research session

---

## Roadmap

- [ ] Gemma 4 model variant selector (2B / 9B / 27B)
- [ ] Multi-document citation with source highlighting in SwiftUI
- [ ] Spend limit controls per session
- [ ] Export research sessions as PDF reports
- [ ] iCloud Drive integration for document sync across devices
- [ ] Team mode — shared local document store over LAN

---

## License

MIT
