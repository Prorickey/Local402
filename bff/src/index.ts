import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import { ConfigError, loadConfig } from "./config.js";
import { CoinbaseService } from "./coinbase.js";
import { AmountError, formatUsdc, parseUsdcAmount, usdToUsdcAtomic } from "./money.js";
import { tavilySearch } from "./tavily.js";
import { X402Service } from "./x402.js";

/**
 * Local402 BFF entrypoint.
 *
 * Exposes exactly four broker endpoints used by the macOS app's
 * CoinbaseService. All Coinbase secrets stay here; the app only sees public
 * data (addresses, balances, tx hashes).
 */

const EVM_ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;

/** Typed validation error surfaced as HTTP 400 by the error middleware. */
class BadRequestError extends Error {
  readonly status = 400;
}

function assertAddress(value: unknown, field: string): `0x${string}` {
  if (typeof value !== "string" || !EVM_ADDRESS_RE.test(value)) {
    throw new BadRequestError(`${field} must be a valid 0x EVM address`);
  }
  return value as `0x${string}`;
}

function requireObjectBody(req: Request): Record<string, unknown> {
  if (typeof req.body !== "object" || req.body === null || Array.isArray(req.body)) {
    throw new BadRequestError("request body must be a JSON object");
  }
  return req.body as Record<string, unknown>;
}

async function main(): Promise<void> {
  const config = loadConfig();
  const coinbase = new CoinbaseService(config);
  const x402 = new X402Service(config, coinbase);

  // Resolve the treasury up front so we fail fast on bad credentials.
  const treasuryAddress = await coinbase.initTreasury();
  console.log(
    `[startup] treasury "${config.treasuryAccount}" -> ${treasuryAddress} on ${config.network}`,
  );

  const app = express();
  app.use(express.json({ limit: "16kb" }));

  // Native app needs no CORS, but allow localhost for local testing tools.
  app.use(
    cors({
      origin: [/^http:\/\/localhost(:\d+)?$/, /^http:\/\/127\.0\.0\.1(:\d+)?$/],
    }),
  );

  // Request logging.
  app.use((req: Request, _res: Response, next: NextFunction) => {
    console.log(`[req] ${req.method} ${req.path}`);
    next();
  });

  app.get("/health", (_req: Request, res: Response) => {
    res.json({ ok: true, network: config.network, treasury: treasuryAddress });
  });

  /**
   * POST /wallet/create -> create a CDP server wallet (EVM account).
   * Response: { address, walletId }
   */
  app.post(
    "/wallet/create",
    asyncHandler(async (_req: Request, res: Response) => {
      const wallet = await coinbase.createWallet();
      res.status(201).json(wallet);
    }),
  );

  /**
   * GET /wallet/:address/balance -> USDC balance on Base for :address.
   * Response: { address, usdc: "12.340000" }
   */
  app.get(
    "/wallet/:address/balance",
    asyncHandler(async (req: Request, res: Response) => {
      const address = assertAddress(req.params.address, "address");
      const usdc = await coinbase.getUsdcBalance(address);
      res.json({ address, usdc });
    }),
  );

  /**
   * POST /fund { address, amountUSD, applePayToken? }
   * Transfers amountUSD of USDC from the TREASURY wallet to address on Base.
   * Response: { txHash, creditedUSD }
   *
   * NOTE: applePayToken is logged for audit but NOT captured. There is no PSP
   * in this build, so no real fiat is charged — the native Apple Pay sheet is
   * presented for UX only and the treasury moves real USDC unconditionally.
   */
  app.post(
    "/fund",
    asyncHandler(async (req: Request, res: Response) => {
      const body = requireObjectBody(req);
      const address = assertAddress(body.address, "address");

      let amountAtomic = usdToUsdcAtomic(body.amountUSD);

      // Server-side hard cap. Never trust the client's amount.
      const capAtomic = BigInt(config.maxFundUsd) * 1_000_000n;
      if (amountAtomic > capAtomic) {
        amountAtomic = capAtomic; // clamp to the cap rather than reject
      }

      // Audit-log (do not capture) the Apple Pay token if present.
      if (typeof body.applePayToken === "string" && body.applePayToken.length > 0) {
        console.log(
          `[fund][audit] applePayToken present (len=${body.applePayToken.length}) for ${address} — NOT captured (no PSP)`,
        );
      }

      const creditedUSD = formatUsdc(amountAtomic);
      const { txHash } = await coinbase.treasuryTransferUsdc(address, amountAtomic);
      console.log(`[fund] sent ${creditedUSD} USDC to ${address} tx=${txHash}`);
      res.json({ txHash, creditedUSD });
    }),
  );

  /**
   * POST /x402/pay { resource, label, amount, from }
   * Settles a real x402 micro-payment of `amount` USDC on Base.
   * Response: { txHash, amount, resource, label }
   */
  app.post(
    "/x402/pay",
    asyncHandler(async (req: Request, res: Response) => {
      const body = requireObjectBody(req);
      const resource = body.resource;
      const label = body.label;
      if (typeof resource !== "string" || resource.length === 0) {
        throw new BadRequestError("resource must be a non-empty string");
      }
      if (typeof label !== "string" || label.length === 0) {
        throw new BadRequestError("label must be a non-empty string");
      }
      const from = assertAddress(body.from, "from");
      const amountAtomic = parseUsdcAmount(body.amount);

      // Sanity cap: x402 calls are micro-payments. Reject anything >= $10.
      if (amountAtomic >= 10_000_000n) {
        throw new BadRequestError("x402 amount exceeds micro-payment limit ($10)");
      }

      const result = await x402.settle({ resource, label, amountAtomic, from });
      console.log(
        `[x402] settled ${result.amount} USDC for "${label}" (${resource}) tx=${result.txHash}`,
      );
      res.json(result);
    }),
  );

  /**
   * POST /tools/search { query }
   * Performs a REAL Tavily search paid for over x402 from the user's CDP server
   * wallet ($0.01 USDC on Base mainnet, gasless for the payer).
   * Response: { query, answer, results: [{title,url,content,score}], txHash, amount }
   */
  app.post(
    "/tools/search",
    asyncHandler(async (req: Request, res: Response) => {
      const body = requireObjectBody(req);
      const query = body.query;
      if (typeof query !== "string" || query.trim().length === 0) {
        throw new BadRequestError("query must be a non-empty string");
      }
      if (query.length > 2000) {
        throw new BadRequestError("query must be 2000 characters or fewer");
      }

      const result = await tavilySearch(coinbase, config, query.trim());
      console.log(
        `[tools/search] paid ${result.amount} USDC for "${query.trim().slice(0, 60)}" tx=${result.txHash ?? "<none>"} (${result.results.length} results)`,
      );
      res.json(result);
    }),
  );

  // 404 fallback.
  app.use((_req: Request, res: Response) => {
    res.status(404).json({ error: "Not found" });
  });

  // Centralized error handler -> JSON { error } with proper status codes.
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof BadRequestError || err instanceof AmountError) {
      res.status(400).json({ error: err.message });
      return;
    }
    const message = err instanceof Error ? err.message : "Internal server error";
    console.error("[error]", message);
    res.status(500).json({ error: message });
  });

  app.listen(config.port, () => {
    console.log(`[startup] Local402 BFF listening on http://localhost:${config.port}`);
  });
}

/** Wrap async route handlers so rejected promises reach the error middleware. */
function asyncHandler(
  fn: (req: Request, res: Response) => Promise<void>,
): (req: Request, res: Response, next: NextFunction) => void {
  return (req, res, next) => {
    fn(req, res).catch(next);
  };
}

main().catch((err: unknown) => {
  if (err instanceof ConfigError) {
    console.error(`[config] ${err.message}`);
  } else {
    console.error("[fatal]", err);
  }
  process.exit(1);
});
