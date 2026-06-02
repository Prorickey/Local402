# Coinbase + Apple Pay Integration (as built, `feat/coinbase`)

Onboarding Step 3 (create wallet) and Step 4 (Apple Pay funding) are real, plus real x402 settlement in chat — all **fully in-app, no popups/webviews**, and gated behind `CoinbaseConfig.demoMode` so the UI demo still runs with no keys.

## Why this shape

Coinbase ships **no native Swift SDK**, and the **Onramp** Apple Pay path needs allowlisting we can't get for a hackathon. But the pieces we need don't require that: **CDP Server Wallets** and the **x402 facilitator** work with just an API key. So we **skip Onramp entirely** and decouple the Apple Pay sheet from funding.

- **Wallet:** the BFF silently provisions a **CDP server wallet** for the user (no Coinbase login).
- **Funding:** a **native macOS Apple Pay sheet** (our own Merchant ID) presents in-app; on authorize, the **BFF treasury transfers real USDC** on **Base mainnet** to the user's wallet. Fiat capture is **mocked** (no PSP), so no real dollars are charged but the USDC is real.
- **Agent payments:** real **x402** — the BFF settles EIP-3009 USDC micro-payments via the facilitator.

## Architecture

```
Local402.app (native SwiftUI, no webview)
  AppState → CoinbaseServicing  (Mock in demo, Live → BFF otherwise)
          → ApplePayFundingController (PassKit, native sheet)
                         │ HTTPS (network.client entitlement)
                         ▼
  BFF (bff/, Node+TS, holds CDP key + treasury key)
    POST /wallet/create            → CDP server wallet → {address, walletId}
    GET  /wallet/:address/balance  → USDC on Base       → {usdc}
    POST /fund {address, amountUSD}→ treasury ─USDC─► user → {txHash}
    POST /x402/pay {resource,...}  → facilitator settle   → {txHash}
                         ▼
  Coinbase CDP (Server Wallets + x402 facilitator) + Base mainnet USDC
```

## Swift layer (`Local402/Services/`)
- `CoinbaseConfig.swift` — public config: `bffURL`, `merchantID`, `network = "base"`, **`demoMode`** (default `true`).
- `CoinbaseModels.swift` — `protocol CoinbaseServicing` + domain types (`ServerWallet`, `FundReceipt`, `X402Envelope`, `PaymentReceipt`, `CoinbaseServiceError`).
- `LiveCoinbaseService.swift` — `URLSession` REST client to the BFF (string-encoded decimals).
- `MockCoinbaseService.swift` — deterministic in-memory simulation (DEMO_MODE).
- `ApplePayFundingController.swift` — `PKPaymentAuthorizationController`; `fund(amountUSD:settle:)` presents the native sheet and runs the BFF settle closure on authorize.

State/views wired in `AppState` (chooses Mock vs Live by `demoMode`, injects `coinbase` + `applePay`), `OnboardingState` (`CoinbaseConnectionState`: `.disconnected/.creating/.connected(address)/.failed`; `FundingState`: `.idle/.presentingApplePay/.settling/.funded(txHash)/.failed`), `WalletStore` (real address + `refreshBalance()`), `ChatStore` (real `payX402` loop when not demo), and the two onboarding step views.

## Backend (`bff/`, Node + TypeScript)
- `@coinbase/cdp-sdk` for server wallets + USDC transfer on Base; `viem` for balance reads; `@coinbase/x402` for settlement; Express.
- Endpoints match the Swift client exactly; amounts string-encoded (6dp), validated + **fund cap (default $200)** server-side.
- Env (`.env`, see `.env.example`): `CDP_API_KEY_ID/SECRET`, `CDP_WALLET_SECRET`, `TREASURY_ACCOUNT`, `NETWORK=base`, `USDC_CONTRACT`, `PORT`. **Secrets live only here.**
- Apple Pay token is **audit-logged, not captured** (documented in `src/index.ts`/`x402.ts`).

## Entitlements
`Local402/Local402.entitlements` (wired via `CODE_SIGN_ENTITLEMENTS` in both app configs): app-sandbox, `network.client`, and `com.apple.developer.in-app-payments = [merchant.tech.hiant.Local402]`.

## Setup to go live (flip `demoMode = false`)
1. Apple: create Merchant ID `merchant.tech.hiant.Local402` + Apple Pay Payment Processing Certificate; enable the Apple Pay capability (Team `PS96HNX5KD`).
2. CDP: project + API key/secret; enable Server Wallets + x402 facilitator. Create a **treasury** server wallet and pre-fund it with a small real USDC balance on Base mainnet.
3. Deploy `bff/` with the env vars; set `CoinbaseConfig.bffURL` to it.
4. Set `CoinbaseConfig.demoMode = false`, build with the entitlements.

## Verify
- **Demo (`demoMode = true`):** onboarding + funding + chat run fully simulated, no keys/network — the live-demo safety net.
- **Live:** Step 3 shows a real server-wallet address; Step 4 → native Apple Pay sheet (no window) → treasury USDC arrives, `FundingState == .funded(txHash)`, balance refreshes from chain; chat paid tools settle real x402 (real tx hashes), balance drops on-chain.
- No `WKWebView`/`ASWebAuthenticationSession` in the app (grep) — confirms the no-popup requirement.
