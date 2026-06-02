# Local402

> A fully local, privacy-first desktop research agent built in Swift. Your documents never leave your machine. Your reasoning never leaves your machine. Only your deliberate, paid search queries do — and you pay for them, on-chain, exactly once.

---

## What It Is

Local402 is a native macOS desktop app that combines four things into a single interface:

1. **A local LLM** — an open-weights model (Qwen2.5 / Llama 3.2) running entirely on your Apple Silicon hardware via **MLX**, streaming tokens in real time.
2. **A private RAG document store** — drop in PDFs that are chunked, embedded, and queried locally, then fed to the model as grounding context with citations.
3. **Two agent tools** the model calls itself, mid-reply:
   - `search_documents` — free, on-device retrieval over your own files.
   - `web_search` — a **real, paid** Tavily web search settled over **Coinbase's x402** micropayment rail on Base mainnet.
4. **A real x402 wallet** — a Coinbase CDP server wallet, provisioned silently and funded in-app, that pays for each web search in USDC and shows the spend inline.

No data leaves your machine unless the model deliberately asks the web a question — and when it does, you pay exactly once, in USDC, for exactly what was asked.

---

## Why Local

The local model is the privacy boundary. When you feed private documents (contracts, financials, medical records, internal reports) into a hosted LLM, your full context window — every document, every reasoning step — leaves your machine before any search is even formed.

With Local402, the model processes everything on-device on Apple Silicon's GPU via MLX. The only signal that ever leaves is a final search query, deliberately emitted by the model as a tool call, with a micropayment attached.

**Privacy surface comparison:**

| | Hosted LLM + Search | Local402 |
|---|---|---|
| Your documents | Sent to provider | Stay on device |
| Reasoning chain | Sent to provider | Stays on device |
| Search queries | Sent to provider + search API | Sent to a search API only, via x402 |
| Provider data logging | Per their ToS | None |
| Variable cost | Tokens + search | Search only (USDC, on-chain) |

---

## Core Features

### On-Device LLM
- Real MLX inference on Apple Silicon — tokens stream live as the model generates them.
- Pick your model during onboarding; weights download once from Hugging Face on first chat.
- Download/load progress is surfaced right in the chat bubble before the first token.
- Tool-calling is native: `mlx-swift-lm`'s `ChatSession` drives the streaming tool-call loop — detect, dispatch, feed the result back, resume — all inside one stream.

### Agent Tools (both real)
- **`search_documents`** — free and fully on-device. The model uses it first for anything answerable from your own files; hits come back as inline **citations** ("handbook.pdf · p.3").
- **`web_search`** — a billed tool. When local context isn't enough, the model calls it; the app runs a **real Tavily search settled over x402** (a real USDC micropayment on Base), drops an **inline payment pill** into the answer, debits the wallet, and refreshes the on-chain balance. The system prompt steers the model to prefer your documents and only pay for the web when it genuinely needs fresh external data.

### Private RAG Document Store
- Drop in PDFs; text is extracted (PDFKit), chunked, and embedded **locally**.
- Embeddings use Apple's on-device `NaturalLanguage` model — no cloud embedding service.
- Vectors live in a local SQLite store with cosine-similarity search.
- The engine is initialized at app launch (not just when the RAG screen is open), so the model's document tool works from the first message.
- A dedicated **RAG terminal** lets you add/remove documents, run retrieval queries, and inspect stored chunks + embeddings.

### Real x402 Coinbase Wallet
- A **CDP server wallet** is provisioned silently during onboarding — no Coinbase login, no terminal, no `.env` for the user, no CLI.
- Funding presents a native **Apple Pay** sheet in-app (no popups/webviews); a backend treasury delivers **real USDC on Base mainnet**.
- Agent web searches settle as **real x402 payments** via the Coinbase facilitator (EIP-3009), with verifiable Base transaction hashes.
- The Wallet tab shows live balance, address, and per-query spend history; each answer shows a "Spent $… on this answer" chip.

### Persistent Conversations
- A real, Copilot-style history sidebar: create new chats, switch between them, delete them.
- Conversations are grouped by day (Today / Yesterday / Previous 7 days / Older) and titled from your first message.
- Every transcript — text, citations, and payments — is persisted to disk under Application Support and restored on relaunch.

### Native macOS Experience
- SwiftUI, resizable and desktop-native, with a dark-blue, Microsoft-Copilot-inspired "Fluent" theme (acrylic chrome).
- In-app top bar with **Chat**, **RAG**, **Wallet**, and **Settings** tabs.
- App Sandbox on; hardened runtime; Apple Pay + outbound-network entitlements.

---

## Core Loop — Agentic Research

1. You submit a query.
2. The on-device model loads (first run downloads the weights from Hugging Face) and starts streaming.
3. The model calls `search_documents`; local RAG returns the most relevant chunks, surfaced as citations.
4. The model answers from local context — free and private — **or** decides it needs the web.
5. If so, it calls `web_search`; the app runs a real Tavily search, settles an x402 USDC micropayment on Base, and feeds the results back.
6. The final answer is grounded in both private and public sources, with citations and a visible, on-chain cost.

---

## Architecture

Local402 is a native SwiftUI app plus a tiny backend-for-frontend (BFF) that holds the Coinbase secrets. **No secrets ship in the app.**

```
Local402.app (SwiftUI, native — no webviews)
  AppState ─ owns wallet, RAG, LLM, conversations, Coinbase service
    │
    ├─ LLMStore ──► LLMEngine (actor)        on-device MLX model + ChatSession
    │                 ├─ search_documents ──► RAGStore ─► RAGEngine (actor)
    │                 │                          extract → chunk → embed → SQLite
    │                 └─ web_search ─────────► CoinbaseServicing.search
    │                                            │ (real Tavily over x402)
    ├─ ConversationManager ─► ConversationStore (actor)   JSON transcripts on disk
    └─ WalletStore / OnboardingState / ApplePayFundingController (PassKit)
                         │ HTTPS (network.client entitlement)
                         ▼
  BFF (bff/, Node + TypeScript — holds CDP key + treasury key)
    POST /wallet/create            → CDP server wallet
    GET  /wallet/:address/balance  → USDC balance on Base
    POST /fund                     → treasury ──USDC──► user wallet
    POST /x402/pay                 → settle EIP-3009 via facilitator
    POST /tools/search             → real Tavily search paid over x402
                         ▼
  Coinbase CDP (Server Wallets + x402 facilitator) · Base mainnet USDC · Tavily
```

Key seams:

- **`LLM/LLMEngine.swift`** — an `actor` that downloads/loads an MLX model and runs a tool-enabled `ChatSession`, exposing replies as an `AsyncThrowingStream<String, Error>`. Handles `search_documents` and `web_search` dispatch and reports citations + payments back to the UI.
- **`LLM/AgentTool.swift`** — the tool registry and JSON schemas the model sees.
- **`State/LLMStore.swift`** — `@MainActor` bridge owning the download → load → ready lifecycle and wiring the RAG + Coinbase backends into the tools.
- **`RAG/RAGEngine.swift` / `State/RAGStore.swift`** — the `actor` + `@MainActor` store for extract → chunk → embed → store → search.
- **`State/ChatStore.swift`** — streams the reply, attaches citations, drops inline payment pills, debits the wallet, and persists transcript checkpoints.
- **`State/ConversationManager.swift` / `Persistence/ConversationStore.swift`** — the persisted conversation list + on-disk JSON store.
- **`Services/`** — `CoinbaseServicing` with a `LiveCoinbaseService` (talks to the BFF) and a `MockCoinbaseService` (in-memory simulation), plus `ApplePayFundingController` (PassKit).
- **`bff/`** — the Node/TypeScript backend (`@coinbase/cdp-sdk`, `@coinbase/x402`, `@x402/fetch`, `viem`) that brokers wallets, funding, x402, and Tavily.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift (Swift Concurrency: actors, async/await, default-MainActor isolation) |
| Desktop framework | SwiftUI (macOS native), Observation framework |
| Local inference | MLX via [`mlx-swift-lm`](https://github.com/ml-explore/mlx-swift-lm) |
| Models | `mlx-community` 4-bit: Qwen2.5 1.5B/3B, Llama 3.2 1B/3B (default: Qwen2.5 1.5B) |
| Tokenizer / chat templates | `swift-transformers` + `swift-jinja` |
| Model download | `swift-huggingface` (Hugging Face Hub) |
| Local embeddings | Apple `NaturalLanguage` (`NLEmbedding`) |
| Vector store | SQLite-backed local vector index (cosine similarity) |
| Tool calling | Native function calling via `ChatSession` |
| Payment rail | **x402** + Coinbase CDP Server Wallets + facilitator (Base mainnet USDC) |
| Web search | **Tavily** (`x402.tavily.com`), paid per call over x402 |
| Funding | Native Apple Pay (PassKit) + CDP treasury USDC transfer |
| Backend (BFF) | Node + TypeScript, Express (`@coinbase/cdp-sdk`, `@coinbase/x402`, `@x402/fetch`, `viem`) |

---

## Privacy Model

Local402 operates on a **minimal disclosure principle**:

- **Documents** — chunked, embedded, and stored in a local SQLite vector index. Never transmitted.
- **Reasoning** — the model's full generation runs in device memory via MLX. Never transmitted.
- **Queries** — only a final, deliberate search string leaves the machine, as a tool call paid over x402.
- **Secrets** — the CDP API key and treasury key live only on the BFF; the app holds no private keys.

Suitable for use cases where data residency matters: legal research, financial analysis, healthcare, and internal business intelligence.

---

## Requirements

- macOS 15 (Sequoia) or later.
- **Apple Silicon (M1 or later)** — required; MLX inference uses the Metal GPU.
- ~1–2 GB free disk for the model weights (downloaded once, on first chat).
- For real payments: a running BFF (`bff/`) with Coinbase CDP credentials and a funded treasury wallet on Base mainnet.

---

## Getting Started

### App

```bash
git clone https://github.com/Prorickey/Local402
open Local402.xcodeproj   # Swift packages resolve automatically
```

On first launch:
1. Pick a local model — it downloads from Hugging Face on first use.
2. Drop in PDFs to populate the local vector store.
3. A Coinbase wallet is provisioned silently; choose a starting balance and fund it.
4. Start chatting — the model grounds answers in your documents and pays for web search only when it needs to.

### Backend (for real payments)

The `bff/` service holds all Coinbase secrets and brokers wallets, funding, x402, and Tavily.

```bash
cd bff
cp .env.example .env     # fill in CDP_API_KEY_ID/SECRET, CDP_WALLET_SECRET, TREASURY_ACCOUNT, …
npm install
npm run dev              # serves http://localhost:8787
```

`CoinbaseConfig.swift` controls the integration mode:

- `demoMode` — when `true`, every Coinbase call is served by an in-memory simulation (no BFF, keys, or network). The UI demo runs end-to-end with no setup; it's the live-demo safety net.
- `simulateApplePay` — when `true` (and `demoMode = false`), wallet creation, balance, and x402 are all **real**; only the native Apple Pay sheet is faked (fund the wallet manually, and the app reads the real on-chain balance after a simulated confirmation). Set to `false` once you have an Apple Merchant ID + signed build for the native PassKit sheet.

> Reaching `http://localhost` from the sandboxed app uses an ATS local-networking exception. For a non-local demo, deploy the BFF behind HTTPS and set `CoinbaseConfig.bffURL` to it.

---

## Roadmap

- [x] Wire `web_search` to Tavily and settle the call over x402
- [x] Surface model download/load progress in the chat UI
- [x] Multi-document citations in the chat answer
- [x] Persistent, on-disk conversation history
- [ ] Productionize native Apple Pay (Merchant ID + signed build) and turn off `simulateApplePay`
- [ ] Deploy the BFF off `localhost` to HTTPS
- [ ] Enforce spend-limit controls per session (the Frugal/Balanced/Thorough selector exists; make it gate spend)
- [ ] OCR for scanned/image-only PDFs
- [ ] Export research sessions as PDF reports
- [ ] Team mode — shared local document store over LAN

---

## License

MIT
