import { formatUnits, parseUnits } from "viem";
import { USDC_DECIMALS } from "./config.js";

/**
 * USDC money helpers. All amounts crossing the API boundary are STRING-encoded
 * with exactly 6 decimal places of precision (USDC's native precision) to avoid
 * floating-point drift. Internally amounts are bigint atomic units (1e-6 USDC).
 */

export class AmountError extends Error {}

const MAX_DECIMALS = USDC_DECIMALS;

/** True for a clean decimal string like "25", "25.0", "0.020000". */
function looksLikeDecimal(value: string): boolean {
  return /^\d+(\.\d+)?$/.test(value);
}

/**
 * Validate + parse a user-supplied USDC amount string into atomic bigint units.
 * Rejects negatives, non-numeric, NaN, and >6 decimal places. Never trusts the
 * client — callers additionally clamp/cap as appropriate.
 */
export function parseUsdcAmount(raw: unknown): bigint {
  if (typeof raw !== "string") {
    throw new AmountError("amount must be a string");
  }
  const trimmed = raw.trim();
  if (!looksLikeDecimal(trimmed)) {
    throw new AmountError(`amount is not a valid non-negative decimal: "${raw}"`);
  }

  const [, fraction = ""] = trimmed.split(".");
  if (fraction.length > MAX_DECIMALS) {
    throw new AmountError(`amount has more than ${MAX_DECIMALS} decimal places: "${raw}"`);
  }

  let atomic: bigint;
  try {
    atomic = parseUnits(trimmed, USDC_DECIMALS);
  } catch {
    throw new AmountError(`amount could not be parsed: "${raw}"`);
  }

  if (atomic <= 0n) {
    throw new AmountError("amount must be greater than zero");
  }
  return atomic;
}

/** Format atomic bigint USDC units to a 6dp decimal string, e.g. "25.000000". */
export function formatUsdc(atomic: bigint): string {
  const formatted = formatUnits(atomic, USDC_DECIMALS);
  const [whole, fraction = ""] = formatted.split(".");
  return `${whole}.${fraction.padEnd(USDC_DECIMALS, "0")}`;
}

/** Convert a validated USD dollar string (same 6dp rules) to atomic USDC units. */
export function usdToUsdcAtomic(raw: unknown): bigint {
  // USDC is a 1:1 USD stablecoin in this build, so the conversion is identity.
  return parseUsdcAmount(raw);
}
