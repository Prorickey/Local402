import type { AppConfig } from "./config.js";
import type { CoinbaseService } from "./coinbase.js";
import { formatUsdc } from "./money.js";

/**
 * x402 micro-payment settlement.
 *
 * BACKGROUND
 * ----------
 * x402 (https://www.x402.org) is an HTTP-native payment protocol. In a full
 * client/server flow, a resource server returns HTTP 402 with payment
 * requirements; the payer signs an EIP-3009 `transferWithAuthorization` for
 * USDC; and a *facilitator* (Coinbase hosts one on Base mainnet, fee-free)
 * verifies + settles that authorization on-chain.
 *
 * WHAT THE BFF DOES HERE
 * ----------------------
 * The BFF is the payer's custodian: the agent's wallet is a CDP server wallet
 * the BFF controls. For the hackathon demo the BFF settles a REAL on-chain USDC
 * micro-payment of `amount` FROM THE USER'S AGENT WALLET to a BFF-controlled
 * x402 receiver address on Base mainnet. This debits the user's own balance
 * (so the wallet visibly draws down as the agent spends) and produces a real,
 * verifiable Base transaction (the user-visible `txHash`) using the exact same
 * fee-free USDC rail the Coinbase facilitator settles on — without requiring a
 * live 402-issuing counterpart resource server during the demo.
 *
 * The receiver defaults to the TREASURY address, so the user's spend
 * recirculates back to the treasury (sustainable across repeated demos); set
 * `X402_RECEIVER_ADDRESS` to direct payments to a distinct receiver instead.
 *
 * PRODUCTION PATH
 * ---------------
 * To settle against a real external resource server, swap `settle()` to:
 *   1. parse the resource's 402 `accepts` requirements,
 *   2. have the CDP server wallet sign the EIP-3009 authorization for `from`,
 *   3. POST it to the Coinbase facilitator (`@coinbase/x402`'s
 *      `createFacilitatorConfig` -> facilitator `/settle`) for on-chain
 *      settlement, and return the facilitator's tx hash.
 * The `@coinbase/x402` and `x402` packages are pinned in package.json for that.
 */

export interface X402PayInput {
  readonly resource: string;
  readonly label: string;
  /** Atomic 6dp USDC units already validated/clamped by the caller. */
  readonly amountAtomic: bigint;
  /** The paying wallet address, recorded for audit. */
  readonly from: `0x${string}`;
}

export interface X402PayResult {
  readonly txHash: string;
  readonly amount: string;
  readonly resource: string;
  readonly label: string;
}

export class X402Service {
  private readonly config: AppConfig;
  private readonly coinbase: CoinbaseService;

  constructor(config: AppConfig, coinbase: CoinbaseService) {
    this.config = config;
    this.coinbase = coinbase;
  }

  /** The BFF-controlled address that demo x402 payments settle TO. */
  private receiver(): `0x${string}` {
    return (this.config.x402ReceiverAddress ??
      this.coinbase.getTreasuryAddress()) as `0x${string}`;
  }

  /**
   * Settle a real on-chain USDC micro-payment for the given resource, debited
   * from the USER's agent wallet. Returns the Base tx hash plus the 6dp amount.
   */
  async settle(input: X402PayInput): Promise<X402PayResult> {
    const { txHash } = await this.coinbase.userTransferUsdc(
      this.receiver(),
      input.amountAtomic,
    );

    return {
      txHash,
      amount: formatUsdc(input.amountAtomic),
      resource: input.resource,
      label: input.label,
    };
  }
}
