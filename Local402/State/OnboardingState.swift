//
//  OnboardingState.swift
//  Local402
//
//  Observable state machine for the onboarding flow. Step 3 (wallet creation)
//  and Step 4 (Apple Pay funding) are driven by the injected CoinbaseServicing
//  + ApplePayFundingController. In demo mode both are simulated; in live mode
//  they provision a real CDP server wallet and settle a treasury USDC transfer.
//

import Foundation
import Observation
import os

/// Lifecycle of the silent server-wallet provisioning (Step 3).
enum CoinbaseConnectionState: Equatable {
    case disconnected
    case creating
    case connected(address: String)
    case failed(String)
}

/// Lifecycle of the wallet-funding transaction (Step 4).
enum FundingState: Equatable {
    case idle
    case presentingApplePay
    case settling
    case funded(txHash: String)
    case failed(String)
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .model

    // Step A — model selection
    var selectedModel: LLMModelOption?
    var downloadProgress: Double = 0      // 0...1
    var isDownloading = false
    var isModelReady = false

    // Step B — company data
    var files: [ContextFile] = MockFiles.seeded

    // Step C-1 — Coinbase wallet provisioning
    var coinbase: CoinbaseConnectionState = .disconnected

    // Step C-2 — funding
    var fundingAmount: Decimal = 25
    var funding: FundingState = .idle

    private let coinbaseService: any CoinbaseServicing
    private let applePay: ApplePayFundingController

    private var downloadTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var fundTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "Onboarding")

    /// Callback fired when a real server wallet is provisioned, so AppState can
    /// adopt it into the shared WalletStore. No-op by default (keeps previews simple).
    var onWalletProvisioned: (ServerWallet) -> Void = { _ in }

    /// Fired when funding settles, so AppState can refresh the real on-chain
    /// balance (used by the simulated-Apple-Pay path where funds arrive manually).
    var onFundingSettled: () -> Void = {}

    /// `coinbase` and `applePay` are main-actor isolated, so they can't be default
    /// arguments (those evaluate in the caller's isolation). They're resolved here
    /// when omitted — keeps `OnboardingState()` usable in previews.
    init(
        coinbase: (any CoinbaseServicing)? = nil,
        applePay: ApplePayFundingController? = nil
    ) {
        self.coinbaseService = coinbase ?? MockCoinbaseService()
        self.applePay = applePay ?? ApplePayFundingController()
    }

    /// The provisioned wallet address, if the connection step has completed.
    var walletAddress: String? {
        if case .connected(let address) = coinbase { return address }
        return nil
    }

    // MARK: - Gating

    /// Whether the user may advance from the current step.
    var canContinue: Bool {
        switch step {
        case .model: return isModelReady
        case .data: return !files.isEmpty
        case .coinbase:
            if case .connected = coinbase { return true }
            return false
        case .funding:
            if case .funded = funding { return true }
            return false
        case .complete: return true
        }
    }

    // MARK: - Navigation

    func advance() {
        guard canContinue, let next = step.next else { return }
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    // MARK: - Step A: model download simulation

    func selectModel(_ model: LLMModelOption) {
        guard selectedModel?.id != model.id else { return }
        downloadTask?.cancel()
        selectedModel = model
        isModelReady = false
        downloadProgress = 0
        startDownload()
    }

    private func startDownload() {
        isDownloading = true
        downloadTask = Task { [weak self] in
            guard let self else { return }
            while self.downloadProgress < 1 {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(120))
                self.downloadProgress = min(1, self.downloadProgress + 0.04)
            }
            self.isDownloading = false
            self.isModelReady = true
        }
    }

    // MARK: - Step B: files

    func addFile() {
        files.append(MockFiles.nextFile(excluding: files))
    }

    func addDroppedFile(_ file: ContextFile) {
        files.append(file)
    }

    func removeFile(_ file: ContextFile) {
        files.removeAll { $0.id == file.id }
    }

    // MARK: - Step C-1: silent server-wallet provisioning

    /// Silently provisions a CDP server wallet (live) or a simulated one (demo).
    /// Cancellable; transitions `.disconnected → .creating → .connected/.failed`.
    func connectCoinbase() {
        switch coinbase {
        case .creating, .connected:
            return
        case .disconnected, .failed:
            break
        }

        coinbase = .creating
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            guard let self else { return }
            do {
                let wallet = try await self.coinbaseService.createServerWallet()
                if Task.isCancelled { return }
                self.coinbase = .connected(address: wallet.address)
                self.onWalletProvisioned(wallet)
                self.logger.info("Provisioned wallet \(wallet.address, privacy: .public)")
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                self.logger.error("Wallet provisioning failed: \(error.localizedDescription, privacy: .public)")
                self.coinbase = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: - Step C-2: funding

    /// Funds the provisioned wallet. In demo mode the flow is simulated end to
    /// end (the mock service bumps its in-memory balance). In live mode it
    /// presents the native Apple Pay sheet, then settles a treasury USDC transfer
    /// through the BFF, surfacing the real tx hash.
    func fundWallet() {
        guard case .idle = funding, let address = walletAddress else { return }

        fundTask?.cancel()
        fundTask = Task { [weak self] in
            guard let self else { return }
            if CoinbaseConfig.demoMode {
                await self.fundSimulated(address: address)
            } else if CoinbaseConfig.simulateApplePay {
                await self.fundSimulatedApplePay(address: address)
            } else {
                await self.fundLive(address: address)
            }
        }
    }

    /// Real wallet/x402, but the Apple Pay sheet is simulated (no Merchant ID
    /// yet). We don't move funds here — the wallet is funded manually/out of
    /// band — so we play the authorization + settling animation, then ask
    /// AppState to read the real on-chain balance.
    private func fundSimulatedApplePay(address: String) async {
        funding = .presentingApplePay
        try? await Task.sleep(for: .seconds(1.4))   // "Apple Pay" sheet
        if Task.isCancelled { return }
        funding = .settling
        try? await Task.sleep(for: .seconds(1.0))   // settling
        if Task.isCancelled { return }
        funding = .funded(txHash: Self.fakeTxHash())
        onFundingSettled()
    }

    /// Demo path: brief settling animation, then a fabricated tx hash. The mock
    /// service is still asked to fund so its balance reflects the credit.
    private func fundSimulated(address: String) async {
        funding = .settling
        try? await Task.sleep(for: .seconds(1.8))
        if Task.isCancelled { return }
        do {
            let receipt = try await coinbaseService.fund(
                address: address,
                amountUSD: fundingAmount,
                applePayToken: nil
            )
            if Task.isCancelled { return }
            funding = .funded(txHash: receipt.txHash)
        } catch {
            if Task.isCancelled { return }
            logger.error("Simulated funding failed: \(error.localizedDescription, privacy: .public)")
            funding = .funded(txHash: Self.fakeTxHash())
        }
    }

    /// Live path: native Apple Pay sheet → BFF treasury transfer → real tx hash.
    private func fundLive(address: String) async {
        funding = .presentingApplePay
        let amount = fundingAmount
        do {
            let txHash = try await applePay.fund(amountUSD: amount) { [coinbaseService] token in
                let receipt = try await coinbaseService.fund(
                    address: address,
                    amountUSD: amount,
                    applePayToken: token
                )
                return receipt.txHash
            }
            if Task.isCancelled { return }
            funding = .funded(txHash: txHash)
        } catch CoinbaseServiceError.applePayCancelled {
            if Task.isCancelled { return }
            logger.info("Apple Pay cancelled by user")
            funding = .idle
        } catch {
            if Task.isCancelled { return }
            logger.error("Live funding failed: \(error.localizedDescription, privacy: .public)")
            funding = .failed(Self.message(for: error))
        }
    }

    /// Resets a failed funding attempt back to amount entry.
    func resetFunding() {
        guard case .failed = funding else { return }
        funding = .idle
    }

    /// Returns to `.disconnected` so a failed provisioning can be retried.
    func retryConnect() {
        coinbase = .disconnected
        connectCoinbase()
    }

    // MARK: - Helpers

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func fakeTxHash() -> String {
        let hex = "0123456789abcdef"
        let body = (0..<40).compactMap { _ in hex.randomElement().map(String.init) }.joined()
        return "0x\(body)"
    }
}
