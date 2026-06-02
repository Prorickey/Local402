//
//  OnboardingState.swift
//  Local402
//
//  Observable state machine for the onboarding flow (all simulated).
//

import Foundation
import Observation

/// Simulated Coinbase connection lifecycle.
enum CoinbaseConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

/// Simulated wallet-funding transaction lifecycle.
enum FundingState: Equatable {
    case idle
    case confirming
    case funded(txHash: String)
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

    // Step B — company data (mirrors the real on-device vector store)
    var files: [ContextFile] = []

    // Step C-1 — Coinbase auth
    var coinbase: CoinbaseConnectionState = .disconnected

    // Step C-2 — funding
    var fundingAmount: Decimal = 25
    var funding: FundingState = .idle

    private var downloadTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var fundTask: Task<Void, Never>?

    // MARK: - Gating

    /// Whether the user may advance from the current step.
    var canContinue: Bool {
        switch step {
        case .model: return isModelReady
        case .data: return !files.isEmpty
        case .coinbase: return coinbase == .connected
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

    /// Fully reset the flow so onboarding can be re-run from scratch. Cancels
    /// any in-flight simulations and clears the mirrored file list (the real
    /// vector store is untouched — the data step re-syncs from it on appear).
    func reset() {
        downloadTask?.cancel()
        connectTask?.cancel()
        fundTask?.cancel()

        step = .model
        selectedModel = nil
        downloadProgress = 0
        isDownloading = false
        isModelReady = false
        files = []
        coinbase = .disconnected
        fundingAmount = 25
        funding = .idle
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

    /// Rebuild the mirrored file list from the documents actually in the vector
    /// store. ContextFile ids are derived from the document id, so SwiftUI keeps
    /// stable identity across refreshes and a chip's removal maps back to a doc.
    func syncDocuments(_ documents: [DocumentMeta]) {
        files = documents.map { doc in
            ContextFile(
                id: UUID(uuidString: doc.id) ?? UUID(),
                fileName: doc.filename,
                sizeBytes: doc.sizeBytes
            )
        }
    }

    // MARK: - Step C-1: Coinbase

    func connectCoinbase() {
        guard coinbase == .disconnected else { return }
        coinbase = .connecting
        connectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, !Task.isCancelled else { return }
            self.coinbase = .connected
        }
    }

    // MARK: - Step C-2: funding

    func fundWallet() {
        guard case .idle = funding, coinbase == .connected else { return }
        funding = .confirming
        fundTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard let self, !Task.isCancelled else { return }
            self.funding = .funded(txHash: OnboardingState.fakeTxHash())
        }
    }

    private static func fakeTxHash() -> String {
        let hex = "0123456789abcdef"
        let body = (0..<40).map { _ in String(hex.randomElement()!) }.joined()
        return "0x\(body)"
    }
}
