# Local402 BFF

Backend-for-frontend (Node + TypeScript) that brokers **all** Coinbase Developer
Platform (CDP) calls for the Local402 macOS app. The CDP API secret, the wallet
secret, and the treasury server wallet live **only here** — no secrets ship in
the native app. The app talks to this service over plain REST.

## Why a BFF

The macOS app is fully native (no WKWebView). It must never hold the CDP secret
or the treasury private key. This service holds them, validates every request,
caps amounts, and returns only public data (addresses, balances, tx hashes) to
the app.

## Endpoints

| Method | Path | Body | Returns |
|---|---|---|---|
| `POST` | `/wallet/create` | – | `{ address, walletId }` |
| `GET`  | `/wallet/:address/balance` | – | `{ address, usdc: "12.340000" }` |
| `POST` | `/fund` | `{ address, amountUSD: "25.00", applePayToken? }` | `{ txHash, creditedUSD: "25.000000" }` |
| `POST` | `/x402/pay` | `{ resource, label, amount: "0.02", from }` | `{ txHash, amount, resource, label }` |
| `GET`  | `/health` | – | `{ ok, network, treasury }` |

All USDC amounts crossing the boundary are **string-encoded with 6 decimal
places** (USDC's native precision). Inputs are validated and clamped
server-side; the client is never trusted.

### Mapping to the app's `CoinbaseService`

| App `CoinbaseService` method | BFF endpoint |
|---|---|
| `createWallet()` | `POST /wallet/create` |
| `balance(address:)` | `GET /wallet/:address/balance` |
| `fund(address:amount:applePayToken:)` | `POST /fund` |
| `payX402(envelope:)` | `POST /x402/pay` |

## How funding settles (Base mainnet)

`POST /fund` moves **real USDC** from the **treasury** CDP server wallet to the
user's wallet via `account.transfer({ to, amount, token: "usdc", network: "base" })`.
Base USDC transfers are fee-free.

The optional `applePayToken` is **logged for audit but NOT captured** — there is
**no payment service provider (PSP)** in this build. The native Apple Pay sheet
is presented for UX only; **no real dollars are charged.** The treasury simply
sends USDC. The amount is re-validated and **hard-capped at `MAX_FUND_USD`
(default $200)** server-side; over-cap requests are clamped down to the cap.

## How x402 settles (Base mainnet)

`POST /x402/pay` settles a **real on-chain USDC micro-payment** of `amount` from
the treasury server wallet to a **BFF-controlled x402 receiver** on Base mainnet
(defaults to the treasury's own address — settle-to-self — so the demo never
loses funds; set `X402_RECEIVER_ADDRESS` for a distinct receiver). This produces
a real, verifiable Base transaction (`txHash`) on the same fee-free USDC rail the
Coinbase x402 facilitator settles on, without needing a live 402-issuing
counterpart during the demo. `amount` is capped at `< $10` (micro-payment).

The production path (sign EIP-3009 `transferWithAuthorization` with the CDP
server wallet and settle via the Coinbase facilitator from `@coinbase/x402`) is
documented in `src/x402.ts`; the `@coinbase/x402` and `x402` packages are pinned
for it.

## SDK / dependencies (pinned)

- **`@coinbase/cdp-sdk` `1.51.0`** — CDP v2 Server Wallets: `new CdpClient({ apiKeyId, apiKeySecret, walletSecret })`, `cdp.evm.createAccount()`, `cdp.evm.getOrCreateAccount({ name })`, `account.transfer({ to, amount, token: "usdc", network: "base" })`.
- **`@coinbase/x402` `2.1.0`** + **`x402` `1.2.0`** — Coinbase x402 facilitator + protocol types (production settlement path).
- **`viem` `2.52.0`** — `parseUnits`/`formatUnits` for 6dp math and a `balanceOf` read against Base USDC (works for any address).
- **`express` `4.22.2`**, **`cors` `2.8.6`**, **`dotenv` `17.4.2`**.

Requires **Node >= 20.19.0** (CDP SDK requirement).

## Setup

```bash
cd bff
cp .env.example .env   # fill in real CDP credentials
npm install
npm run dev            # tsx watch, hot reload
# or
npm run build && npm start
```

### Required env vars

| Var | Purpose |
|---|---|
| `CDP_API_KEY_ID` | CDP Secret API Key id |
| `CDP_API_KEY_SECRET` | CDP Secret API Key secret |
| `CDP_WALLET_SECRET` | CDP v2 Wallet Secret (authorizes signing) |
| `TREASURY_ACCOUNT` | Name of the treasury server account (pre-funded with USDC) |
| `NETWORK` | Must be `base` |
| `USDC_CONTRACT` | Base USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| `PORT` | HTTP port (default `8787`) |
| `BASE_RPC_URL` | optional, defaults to `https://mainnet.base.org` |
| `X402_RECEIVER_ADDRESS` | optional, defaults to treasury address |
| `MAX_FUND_USD` | optional, default `200` |

Pre-fund the treasury account's address with a small real USDC balance on Base
mainnet before testing `/fund` and `/x402/pay`.

## Quick manual test

```bash
curl -s localhost:8787/health
curl -s -XPOST localhost:8787/wallet/create
curl -s localhost:8787/wallet/0xYourAddr/balance
curl -s -XPOST localhost:8787/fund \
  -H 'content-type: application/json' \
  -d '{"address":"0xYourAddr","amountUSD":"25.00"}'
curl -s -XPOST localhost:8787/x402/pay \
  -H 'content-type: application/json' \
  -d '{"resource":"https://api.example/df","label":"Premium data","amount":"0.02","from":"0xYourAddr"}'
```

## Security notes

- Secrets are loaded once via `dotenv` and never returned to the app.
- Every request is validated at the boundary (address format, amount precision,
  caps). Errors return JSON `{ error }` with proper status codes.
- The server fails fast at startup on missing/invalid config or bad credentials.
