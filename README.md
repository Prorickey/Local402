# Local402

**Local402** is a local-first LLM desktop application that gives AI agents real economic reasoning over their own actions. It connects locally-running language models to Coinbase wallets and makes native [x402](https://www.x402.org/) payment calls, so that whenever an agent reaches for a paid API, tool, or piece of data, it can see the price, weigh the cost against the expected value, and decide for itself whether the call is worth making.

Instead of treating every external request as free, agents operate against a real budget — paying per request over HTTP 402 the same way a person weighs whether a purchase is worth it. By keeping the model on your machine and the wallet under your control, Local402 turns abstract "tool use" into accountable, cost-aware decision making where every dollar spent is a deliberate choice the agent can explain.

## Why Local402

- **Local-first** — language models run on your machine; your prompts and data never leave it.
- **Real economic reasoning** — agents see prices up front and weigh cost against expected value before acting.
- **Native x402 payments** — paid APIs, tools, and data are accessed via native [x402](https://www.x402.org/) payment calls over HTTP 402.
- **You hold the wallet** — Coinbase wallets stay under your control, so every payment is authorized and accountable.
- **Explainable spending** — every dollar spent is a deliberate, auditable choice the agent can justify.

## How It Works

1. An agent decides it needs an external API, tool, or piece of data to complete a task.
2. The endpoint responds with an HTTP `402 Payment Required`, exposing the price of the call.
3. Local402 surfaces that price to the locally-running model, which weighs the cost against the expected value of making the call.
4. If the call is worth it, Local402 settles the payment over x402 from a Coinbase wallet under your control and returns the result to the agent.
5. The agent continues, now operating against a real, depleting budget — just like a person managing their own money.

## Tech Stack

- **Platform:** macOS desktop application
- **UI:** SwiftUI
- **Payments:** [x402](https://www.x402.org/) over HTTP 402, settled via Coinbase wallets
- **Models:** locally-running language models

## Getting Started

### Requirements

- macOS
- [Xcode](https://developer.apple.com/xcode/)

### Build & Run

```bash
git clone https://github.com/Prorickey/Local402.git
cd Local402
open Local402.xcodeproj
```

Then build and run the `Local402` scheme from Xcode (⌘R).

## Project Structure

```
Local402/            App source (SwiftUI)
Local402Tests/       Unit tests
Local402UITests/     UI tests
Local402.xcodeproj/  Xcode project
```

## License

See the repository for license details.
