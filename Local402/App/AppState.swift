//
//  AppState.swift
//  Local402
//
//  Central observable coordinator. Owns the Coinbase service, wallet, on-device
//  RAG + LLM, the persisted conversations, and the selected main-app tab.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var selectedTab: AppTab = .chat

    /// Single Coinbase service for the whole app: the in-memory mock in demo
    /// mode, the BFF-backed live client otherwise.
    let coinbase: any CoinbaseServicing

    /// Native Apple Pay presentation controller (PassKit), shared with onboarding.
    let applePay = ApplePayFundingController()

    let wallet: WalletStore
    let onboarding: OnboardingState

    /// On-device RAG document store + retrieval. Powers the RAG terminal AND the
    /// model's `search_documents` tool. Bootstrapped at launch (see init) so the
    /// model can query documents even if the RAG screen is never opened.
    let rag: RAGStore

    /// On-device LLM lifecycle (download → load → ready) and streaming.
    let llm: LLMStore

    /// Owns the real, persisted conversations + the live chat for the selected one.
    let conversations: ConversationManager

    /// The live chat store for the currently selected conversation. Reflects the
    /// conversation manager's selection; reading it here keeps every chat view
    /// pointed at the active transcript when the user switches conversations.
    var chat: ChatStore { conversations.chat }

    /// Mirrors the persisted onboarding flag so views can react. The persisted
    /// source of truth is `@AppStorage` in `RootView`.
    var hasCompletedOnboarding: Bool

    init(hasCompletedOnboarding: Bool = false) {
        let coinbase: any CoinbaseServicing = CoinbaseConfig.demoMode
            ? MockCoinbaseService()
            : LiveCoinbaseService()
        self.coinbase = coinbase

        let wallet = WalletStore(coinbase: coinbase)
        self.wallet = wallet

        let rag = RAGStore()
        self.rag = rag

        let llm = LLMStore()
        self.llm = llm

        let onboarding = OnboardingState(coinbase: coinbase, applePay: applePay)
        self.onboarding = onboarding

        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.conversations = ConversationManager(
            wallet: wallet,
            llm: llm,
            defaultModelName: llm.modelName
        )

        // Let the model query the on-device document store on demand via its
        // `search_documents` tool.
        llm.connectRAG { query, topK in await rag.retrieve(query, topK: topK) }

        // Adopt a provisioned server wallet into the shared wallet store, then
        // refresh its on-chain balance.
        onboarding.onWalletProvisioned = { [weak wallet] serverWallet in
            guard let wallet else { return }
            wallet.adoptWallet(serverWallet)
            Task { await wallet.refreshBalance() }
        }

        // After (simulated) Apple Pay funding, re-read the real on-chain balance
        // — the wallet is funded manually/out of band in this mode.
        onboarding.onFundingSettled = { [weak wallet] in
            guard let wallet else { return }
            Task { await wallet.refreshBalance() }
        }

        // Always initialize the RAG engine at launch (idempotent) so the model's
        // document tool works without first visiting the RAG screen.
        Task { await rag.bootstrap() }
    }

    /// Called when onboarding finishes: applies the selected model + funding to
    /// the live stores, rebuilds chat so the greeting names the chosen model, and
    /// warms up the model so the first reply streams sooner.
    func completeOnboarding() {
        if let model = onboarding.selectedModel {
            llm.modelID = model.id
            llm.modelName = model.name
        }
        conversations.startFreshConversation(modelName: llm.modelName)

        if case .funded = onboarding.funding {
            // In demo mode the mock seed reflects the starting balance directly;
            // in live mode the on-chain balance is the source of truth.
            if CoinbaseConfig.demoMode {
                wallet.addFunds(onboarding.fundingAmount)
            } else {
                Task { await wallet.refreshBalance() }
            }
        }

        hasCompletedOnboarding = true
        selectedTab = .chat

        // Kick off the real model download/load in the background.
        Task { try? await llm.ensureReady() }
    }

    /// Resets onboarding so the flow can be re-run from Settings.
    func restartOnboarding() {
        onboarding.reset()
        hasCompletedOnboarding = false
    }

    var selectedModelName: String {
        onboarding.selectedModel?.name ?? chat.modelName
    }
}
