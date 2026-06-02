import { CdpClient } from "@coinbase/cdp-sdk";
import type { EvmServerAccount } from "@coinbase/cdp-sdk";
import { createPublicClient, http, type PublicClient } from "viem";
import { base } from "viem/chains";
import type { AppConfig } from "./config.js";
import { formatUsdc } from "./money.js";

/**
 * Thin wrapper around the Coinbase CDP v2 Server Wallet SDK.
 *
 * Responsibilities:
 *  - create app-owned EVM server wallets (private keys held by CDP, never here)
 *  - read USDC balances on Base mainnet
 *  - move real USDC from the treasury server wallet to a user wallet
 *
 * SDK reference (pinned @coinbase/cdp-sdk 1.48.3):
 *  - new CdpClient({ apiKeyId, apiKeySecret, walletSecret })
 *  - cdp.evm.createAccount() / cdp.evm.getOrCreateAccount({ name })
 *  - account.transfer({ to, amount: bigint, token: "usdc", network: "base" })
 *  - account.listTokenBalances({ network: "base" })
 */

/** Minimal ERC-20 ABI for the balanceOf fallback read. */
const ERC20_BALANCE_ABI = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export interface CreatedWallet {
  readonly address: string;
  readonly walletId: string;
}

export interface TransferResult {
  readonly txHash: string;
}

/**
 * Defensive extraction of a tx hash from the CDP transfer result, tolerant of
 * minor shape differences across SDK patch versions.
 */
function extractTxHash(result: unknown): string {
  const r = result as Record<string, unknown> | null;
  if (r && typeof r === "object") {
    if (typeof r.transactionHash === "string") return r.transactionHash;
    if (typeof r.hash === "string") return r.hash;
    const tx = r.transaction as Record<string, unknown> | undefined;
    if (tx && typeof tx.transactionHash === "string") return tx.transactionHash;
  }
  throw new Error("CDP transfer did not return a transaction hash");
}

export class CoinbaseService {
  private readonly cdp: CdpClient;
  private readonly config: AppConfig;
  private readonly publicClient: PublicClient;
  private treasuryAddress: string | null = null;

  constructor(config: AppConfig) {
    this.config = config;
    this.cdp = new CdpClient({
      apiKeyId: config.cdpApiKeyId,
      apiKeySecret: config.cdpApiKeySecret,
      walletSecret: config.cdpWalletSecret,
    });
    this.publicClient = createPublicClient({
      chain: base,
      transport: http(config.baseRpcUrl),
    }) as PublicClient;
  }

  /**
   * Resolve (creating if needed) the treasury server account and cache its
   * address. Called once at startup so funding is fast and so we fail early if
   * credentials are wrong.
   */
  async initTreasury(): Promise<string> {
    const account = await this.cdp.evm.getOrCreateAccount({
      name: this.config.treasuryAccount,
    });
    this.treasuryAddress = account.address;
    return account.address;
  }

  getTreasuryAddress(): string {
    if (!this.treasuryAddress) {
      throw new Error("Treasury not initialized");
    }
    return this.treasuryAddress;
  }

  /**
   * Resolve (creating if needed) the USER's CDP server account — the same
   * idempotent `getOrCreateAccount({ name: USER_ACCOUNT })` wallet the BFF
   * provisions elsewhere. Exposed so the x402 payer can use this CDP-custodied
   * account as an EIP-712 signer (its private key stays inside CDP).
   */
  async getUserAccount(): Promise<EvmServerAccount> {
    return this.cdp.evm.getOrCreateAccount({ name: this.config.userAccount });
  }

  /**
   * The viem PublicClient bound to Base mainnet. Exposed so x402 clients can
   * supply on-chain reads (readContract) to the signer composer.
   */
  getPublicClient(): PublicClient {
    return this.publicClient;
  }

  /**
   * Automatically provision the agent's EVM server wallet (CDP Agentic Wallet).
   *
   * Uses `getOrCreateAccount({ name })` so the wallet is created on the first
   * call and the SAME wallet is returned on every subsequent call — idempotent,
   * no user login, no duplicate accounts. Private keys are held by CDP, never
   * here. `name` defaults to the configured `USER_ACCOUNT`; pass a per-user name
   * to scope wallets per end user in a multi-user deployment.
   */
  async createWallet(name?: string): Promise<CreatedWallet> {
    const account = await this.cdp.evm.getOrCreateAccount({
      name: name ?? this.config.userAccount,
    });
    const walletId =
      (account as { name?: string }).name ?? account.address;
    return { address: account.address, walletId };
  }

  /**
   * USDC balance for an arbitrary address on Base mainnet, as a 6dp string.
   *
   * Primary path: viem balanceOf against the configured USDC contract (works
   * for ANY address, including user wallets the SDK doesn't own). This is the
   * authoritative on-chain read.
   */
  async getUsdcBalance(address: `0x${string}`): Promise<string> {
    const atomic = (await this.publicClient.readContract({
      address: this.config.usdcContract,
      abi: ERC20_BALANCE_ABI,
      functionName: "balanceOf",
      args: [address],
    })) as bigint;
    return formatUsdc(atomic);
  }

  /**
   * Transfer `amountAtomic` USDC (atomic 6dp units) from a named CDP server
   * account to `to` on Base mainnet. Returns the on-chain tx hash.
   */
  private async transferUsdcFrom(
    accountName: string,
    to: `0x${string}`,
    amountAtomic: bigint,
  ): Promise<TransferResult> {
    const account = await this.cdp.evm.getOrCreateAccount({ name: accountName });

    const result = await account.transfer({
      to,
      amount: amountAtomic,
      token: "usdc",
      network: this.config.network,
    });

    // Some SDK versions return immediately; wait if the result exposes it.
    const maybeWaitable = result as { wait?: () => Promise<unknown> };
    if (typeof maybeWaitable.wait === "function") {
      await maybeWaitable.wait();
    }

    return { txHash: extractTxHash(result) };
  }

  /** Move USDC from the TREASURY server wallet to `to` (used by /fund). */
  async treasuryTransferUsdc(
    to: `0x${string}`,
    amountAtomic: bigint,
  ): Promise<TransferResult> {
    return this.transferUsdcFrom(this.config.treasuryAccount, to, amountAtomic);
  }

  /**
   * Move USDC from the USER's agent wallet to `to` (used by /x402/pay so the
   * agent genuinely spends from its own balance). Same idempotent
   * getOrCreateAccount({ name: USER_ACCOUNT }) wallet the BFF provisions.
   */
  async userTransferUsdc(
    to: `0x${string}`,
    amountAtomic: bigint,
  ): Promise<TransferResult> {
    return this.transferUsdcFrom(this.config.userAccount, to, amountAtomic);
  }
}
