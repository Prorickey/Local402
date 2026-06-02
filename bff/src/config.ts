import "dotenv/config";

/**
 * Centralized, validated configuration loaded from the environment.
 *
 * Fails fast at startup if any required secret is missing so the server never
 * boots into a half-configured state. Secrets live ONLY here on the server and
 * are never returned to the native app.
 */

export interface AppConfig {
  readonly cdpApiKeyId: string;
  readonly cdpApiKeySecret: string;
  readonly cdpWalletSecret: string;
  readonly treasuryAccount: string;
  readonly userAccount: string;
  readonly network: "base";
  readonly usdcContract: `0x${string}`;
  readonly baseRpcUrl: string;
  readonly x402ReceiverAddress: string | null;
  readonly port: number;
  readonly maxFundUsd: number;
}

/** USDC always uses 6 decimal places. */
export const USDC_DECIMALS = 6;

/** Canonical USDC contract on Base mainnet. */
export const BASE_USDC_CONTRACT =
  "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" as const;

class ConfigError extends Error {}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (value === undefined || value.trim() === "") {
    throw new ConfigError(`Missing required environment variable: ${name}`);
  }
  return value.trim();
}

function optionalEnv(name: string, fallback: string): string {
  const value = process.env[name];
  return value === undefined || value.trim() === "" ? fallback : value.trim();
}

function parsePositiveInt(raw: string, name: string): number {
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n) || n <= 0) {
    throw new ConfigError(`Environment variable ${name} must be a positive integer (got "${raw}")`);
  }
  return n;
}

function isAddress(value: string): value is `0x${string}` {
  return /^0x[0-9a-fA-F]{40}$/.test(value);
}

/**
 * Load and validate config. Throws ConfigError (caught in index.ts) on any
 * misconfiguration so the process exits with a clear message.
 */
export function loadConfig(): AppConfig {
  const network = optionalEnv("NETWORK", "base");
  if (network !== "base") {
    throw new ConfigError(`NETWORK must be "base" for this build (got "${network}")`);
  }

  const usdcContract = optionalEnv("USDC_CONTRACT", BASE_USDC_CONTRACT);
  if (!isAddress(usdcContract)) {
    throw new ConfigError(`USDC_CONTRACT is not a valid 0x address: "${usdcContract}"`);
  }

  const x402Receiver = optionalEnv("X402_RECEIVER_ADDRESS", "");
  if (x402Receiver !== "" && !isAddress(x402Receiver)) {
    throw new ConfigError(`X402_RECEIVER_ADDRESS is not a valid 0x address: "${x402Receiver}"`);
  }

  return {
    cdpApiKeyId: requireEnv("CDP_API_KEY_ID"),
    cdpApiKeySecret: requireEnv("CDP_API_KEY_SECRET"),
    cdpWalletSecret: requireEnv("CDP_WALLET_SECRET"),
    treasuryAccount: requireEnv("TREASURY_ACCOUNT"),
    userAccount: optionalEnv("USER_ACCOUNT", "local402-user"),
    network: "base",
    usdcContract,
    baseRpcUrl: optionalEnv("BASE_RPC_URL", "https://mainnet.base.org"),
    x402ReceiverAddress: x402Receiver === "" ? null : x402Receiver,
    port: parsePositiveInt(optionalEnv("PORT", "8787"), "PORT"),
    maxFundUsd: parsePositiveInt(optionalEnv("MAX_FUND_USD", "200"), "MAX_FUND_USD"),
  };
}

export { ConfigError };
