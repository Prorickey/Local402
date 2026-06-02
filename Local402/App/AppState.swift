//
//  AppState.swift
//  Local402
//
//  Central observable coordinator. Owns the wallet, chat, and onboarding
//  stores and tracks the currently selected main-app tab.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var selectedTab: AppTab = .chat

    let wallet: WalletStore
    let onboarding: OnboardingState

    /// Chat is created lazily once onboarding picks a model, so the greeting
    /// reflects the chosen model. Until then a default is used.
    private(set) var chat: ChatStore

    /// Mirrors the persisted onboarding flag so views can react. The persisted
    /// source of truth is `@AppStorage` in `RootView`.
    var hasCompletedOnboarding: Bool

    init(hasCompletedOnboarding: Bool = false) {
        let wallet = WalletStore()
        self.wallet = wallet
        self.onboarding = OnboardingState()
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.chat = ChatStore(wallet: wallet, modelName: MockModels.all.first?.name ?? "Llama 3.1")
    }

    /// Called when onboarding finishes: applies the selected model + funding to
    /// the live stores and rebuilds chat so the greeting names the chosen model.
    func completeOnboarding() {
        let modelName = onboarding.selectedModel?.name ?? chat.modelName
        chat = ChatStore(wallet: wallet, modelName: modelName)

        if case .funded = onboarding.funding {
            wallet.addFunds(onboarding.fundingAmount)
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
