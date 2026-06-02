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

    /// On-device RAG document store + retrieval (powers the RAG terminal).
    let rag: RAGStore

    /// On-device LLM lifecycle (download → load → ready) and streaming.
    let llm: LLMStore

    /// Chat is rebuilt once onboarding picks a model, so the greeting reflects
    /// the chosen model. Until then the recommended default is used.
    private(set) var chat: ChatStore

    /// Mirrors the persisted onboarding flag so views can react. The persisted
    /// source of truth is `@AppStorage` in `RootView`.
    var hasCompletedOnboarding: Bool

    init(hasCompletedOnboarding: Bool = false) {
        let wallet = WalletStore()
        let rag = RAGStore()
        let llm = LLMStore()
        self.wallet = wallet
        self.rag = rag
        self.llm = llm
        self.onboarding = OnboardingState()
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.chat = ChatStore(wallet: wallet, llm: llm)

        // Let the model query the on-device document store on demand via its
        // `search_documents` tool.
        llm.connectRAG { query, topK in await rag.retrieve(query, topK: topK) }
    }

    /// Called when onboarding finishes: applies the selected model + funding to
    /// the live stores, rebuilds chat so the greeting names the chosen model, and
    /// warms up the model so the first reply streams sooner.
    func completeOnboarding() {
        if let model = onboarding.selectedModel {
            llm.modelID = model.id
            llm.modelName = model.name
        }
        chat = ChatStore(wallet: wallet, llm: llm)

        if case .funded = onboarding.funding {
            wallet.addFunds(onboarding.fundingAmount)
        }

        hasCompletedOnboarding = true
        selectedTab = .chat

        // Kick off the real model download/load in the background.
        Task { try? await llm.ensureReady() }
    }

    /// Resets onboarding so the flow can be re-run from Settings — a true clean
    /// reset (model, wallet, funding, and the mirrored file list).
    func restartOnboarding() {
        onboarding.reset()
        hasCompletedOnboarding = false
    }

    var selectedModelName: String {
        onboarding.selectedModel?.name ?? chat.modelName
    }
}
