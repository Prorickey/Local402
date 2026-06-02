//
//  ChatView.swift
//  Local402
//
//  The chat surface: a slim Copilot-style header, a scrolling message list, and
//  a pinned acrylic prompt bar, with a friendly empty state when no messages
//  exist yet. See DESIGN.md §3–§5.
//

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var chat = appState.chat

        VStack(spacing: 0) {
            header(spendMode: $chat.spendMode)

            Divider()
                .overlay(Theme.color.surfaceStroke)

            if appState.chat.messages.isEmpty {
                emptyState
            } else {
                MessageListView(
                    messages: appState.chat.messages,
                    loadingText: modelLoadingText,
                    loadingProgress: modelLoadingProgress
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            ChatInputBar()
        }
        .background(Theme.color.background)
    }

    // MARK: - Header

    private func header(spendMode: Binding<Int>) -> some View {
        HStack(spacing: Theme.spacing.md) {
            Local402Flourish(size: 16)

            Text("Local402")
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)

            Text(appState.chat.modelName)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
                .lineLimit(1)

            Spacer(minLength: Theme.spacing.lg)

            Local402SpendMode(selection: spendMode)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Model loading status (shown in the streaming bubble)

    private var modelLoadingText: String? {
        guard appState.chat.isStreaming else { return nil }
        switch appState.llm.phase {
        case .downloading: return "Downloading \(appState.llm.modelName)…"
        case .loading: return "Loading \(appState.llm.modelName)…"
        default: return nil
        }
    }

    private var modelLoadingProgress: Double? {
        if case .downloading(let fraction) = appState.llm.phase { return fraction }
        return nil
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.spacing.md) {
            Spacer()

            Local402Flourish(size: 42)

            Text("Start a conversation")
                .font(Theme.font.title)
                .foregroundStyle(Theme.color.textPrimary)

            Text("Ask anything. \(appState.chat.modelName) pays for tools as it works.")
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.spacing.xxl)
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .frame(width: 760, height: 640)
        .preferredColorScheme(.dark)
}
