import { ExactEvmScheme, toClientEvmSigner } from "@x402/evm";
import {
  decodePaymentResponseHeader,
  wrapFetchWithPayment,
  x402Client,
} from "@x402/fetch";
import type { CoinbaseService } from "./coinbase.js";
import type { AppConfig } from "./config.js";

/**
 * Tavily search paid for over the x402 protocol, settled from the USER's
 * CDP server wallet.
 *
 * FLOW
 * ----
 * Tavily exposes a paid search endpoint at `https://x402.tavily.com/search`
 * priced at $0.01 USDC on Base mainnet (eip155:8453). We POST the query; the
 * endpoint replies 402 with payment requirements; the x402 client signs an
 * EIP-3009 `transferWithAuthorization` for USDC and retries with the payment
 * header; Tavily's facilitator settles it on-chain (GASLESS for us — the
 * facilitator submits the tx) and returns 200 with the real Tavily JSON plus a
 * `PAYMENT-RESPONSE` header carrying the settlement tx hash.
 *
 * CDP-WALLET-AS-SIGNER (the crucial bit)
 * --------------------------------------
 * The payer is our CDP server wallet (getOrCreateAccount({ name: USER_ACCOUNT })),
 * whose private key is custodied by CDP — we never hold it. x402's
 * `ClientEvmSigner` only needs `address` + `signTypedData(...)`, and the CDP
 * `EvmServerAccount` already exposes a viem-shaped `signTypedData` that performs
 * the EIP-712 signing remotely inside CDP. We feed that (plus the viem
 * publicClient for optional on-chain reads) into `toClientEvmSigner(...)`, wrap
 * it in `ExactEvmScheme`, and register it on the x402Client for Base mainnet.
 */

const TAVILY_X402_ENDPOINT = "https://x402.tavily.com/search";
const BASE_MAINNET_NETWORK = "eip155:8453";

/** Settlement amount Tavily charges per search: $0.01 USDC (6dp). */
const TAVILY_PRICE = "0.010000";

/** A single Tavily search result (public-safe subset returned to the app). */
export interface TavilyResult {
  readonly title: string;
  readonly url: string;
  readonly content: string;
  readonly score: number;
}

export interface TavilySearchResult {
  readonly query: string;
  readonly answer: string | null;
  readonly results: TavilyResult[];
  /** On-chain settlement tx hash from the PAYMENT-RESPONSE header, if present. */
  readonly txHash: string | null;
  /** 6dp USDC amount paid for this search. */
  readonly amount: string;
}

/** Shape of the relevant fields in Tavily's JSON response. */
interface RawTavilyResponse {
  readonly query?: string;
  readonly answer?: string | null;
  readonly results?: ReadonlyArray<Record<string, unknown>>;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asScore(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

/** Map Tavily's raw result objects to the public-safe subset, defensively. */
function normalizeResults(
  raw: ReadonlyArray<Record<string, unknown>> | undefined,
): TavilyResult[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.map((r) => ({
    title: asString(r.title),
    url: asString(r.url),
    content: asString(r.content),
    score: asScore(r.score),
  }));
}

/**
 * Extract the on-chain settlement tx hash from the `PAYMENT-RESPONSE` header.
 *
 * The header is base64-encoded JSON; `decodePaymentResponseHeader` decodes it to
 * a SettleResponse whose `transaction` field is the tx hash. We fall back to a
 * manual base64-JSON decode if the canonical decoder throws on a vendor-specific
 * shape, so a successful search never fails purely on header parsing.
 */
function extractTxHash(header: string | null): string | null {
  if (!header || header.trim() === "") {
    return null;
  }
  try {
    const decoded = decodePaymentResponseHeader(header);
    if (decoded && typeof decoded.transaction === "string" && decoded.transaction !== "") {
      return decoded.transaction;
    }
  } catch {
    // Fall through to the tolerant manual decode below.
  }
  try {
    const json = Buffer.from(header, "base64").toString("utf8");
    const parsed = JSON.parse(json) as Record<string, unknown>;
    const tx = parsed.transaction ?? parsed.txHash ?? parsed.transactionHash;
    if (typeof tx === "string" && tx !== "") {
      return tx;
    }
  } catch {
    // Header was neither canonical nor base64-JSON — give up gracefully.
  }
  return null;
}

/**
 * Build a payment-enabled fetch that pays from the USER's CDP server wallet.
 *
 * The CDP `EvmServerAccount` supplies `address` + `signTypedData`; the viem
 * publicClient supplies `readContract`. Together they form the x402
 * `ClientEvmSigner`.
 */
async function buildPaidFetch(
  coinbase: CoinbaseService,
): Promise<ReturnType<typeof wrapFetchWithPayment>> {
  const account = await coinbase.getUserAccount();
  const publicClient = coinbase.getPublicClient();

  // CDP account as the x402 client signer: address + remote EIP-712 signing
  // (key stays in CDP), with on-chain reads delegated to the viem publicClient.
  const signer = toClientEvmSigner(
    {
      address: account.address as `0x${string}`,
      signTypedData: (message) =>
        account.signTypedData(
          message as Parameters<typeof account.signTypedData>[0],
        ),
    },
    publicClient,
  );

  const client = new x402Client().register(
    BASE_MAINNET_NETWORK,
    new ExactEvmScheme(signer),
  );

  return wrapFetchWithPayment(fetch, client);
}

/**
 * Perform a REAL Tavily search, paying $0.01 USDC over x402 from the user's CDP
 * server wallet. Returns the real results plus the on-chain settlement tx hash.
 *
 * @throws Error with the upstream status/body when Tavily returns non-200.
 */
export async function tavilySearch(
  coinbase: CoinbaseService,
  _config: AppConfig,
  query: string,
  maxResults = 5,
): Promise<TavilySearchResult> {
  const paidFetch = await buildPaidFetch(coinbase);

  const res = await paidFetch(TAVILY_X402_ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query, max_results: maxResults }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `Tavily x402 search failed (HTTP ${res.status}): ${body.slice(0, 500)}`,
    );
  }

  const data = (await res.json()) as RawTavilyResponse;
  const txHash = extractTxHash(res.headers.get("PAYMENT-RESPONSE"));

  return {
    query: asString(data.query) || query,
    answer: typeof data.answer === "string" ? data.answer : null,
    results: normalizeResults(data.results),
    txHash,
    amount: TAVILY_PRICE,
  };
}
