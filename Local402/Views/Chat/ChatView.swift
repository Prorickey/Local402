//
//  ChatView.swift
//  Local402
//
//  The chat surface: a scrolling message list above a pinned input composer,
//  with a friendly empty state when no messages exist yet.
//

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.chat.messages.isEmpty {
                emptyState
            } else {
                MessageListView(messages: appState.chat.messages)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            ChatInputBar()
        }
        .background(Theme.color.background)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.spacing.md) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.color.accent.opacity(0.8))

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
        .frame(width: 720, height: 640)
        .preferredColorScheme(.dark)
}
