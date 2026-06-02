//
//  AppState.swift
//  Local402
//
//  Central observable coordinator. Owns the Coinbase service, wallet, chat, and
//  onboarding stores and tracks the currently selected main-app tab.
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

    /// On-device RAG document store + retrieval (powers the RAG terminal).
    let rag = RAGStore()

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

        let onboarding = OnboardingState(coinbase: coinbase, applePay: applePay)
        self.onboarding = onboarding

        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.conversations = ConversationManager(
            wallet: wallet,
            coinbase: coinbase,
            defaultModelName: MockModels.all.first?.name ?? "Llama 3.1"
        )

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
    }

    /// Called when onboarding finishes: applies the selected model + funding to
    /// the live stores and rebuilds chat so the greeting names the chosen model.
    func completeOnboarding() {
        let modelName = onboarding.selectedModel?.name ?? chat.modelName
        conversations.startFreshConversation(modelName: modelName)

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
    }

    /// Resets onboarding so the flow can be re-run from Settings.
    func restartOnboarding() {
        onboarding.step = .model
        hasCompletedOnboarding = false
    }

    var selectedModelName: String {
        onboarding.selectedModel?.name ?? chat.modelName
    }
}
