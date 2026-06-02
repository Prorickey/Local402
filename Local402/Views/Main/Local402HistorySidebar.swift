//
//  Local402HistorySidebar.swift
//  Local402
//
//  The collapsible chat-history sidebar — the one genuinely desktop-Copilot
//  pattern. Acrylic Fluent chrome with a "New chat" accent button and grouped
//  conversation rows. Backed by real, persisted conversations via the
//  `ConversationManager`. See DESIGN.md §5.
//

import SwiftUI
import os

struct Local402HistorySidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let logger = Logger(subsystem: "tech.hiant.Local402", category: "HistorySidebar")

    private var manager: ConversationManager { appState.conversations }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            newChatButton

            ForEach(Array(manager.groups.enumerated()), id: \.element.id) { groupIndex, group in
                groupLabel(group.title)
                    .padding(.top, groupIndex == 0 ? Theme.spacing.lg : Theme.spacing.md)

                ForEach(group.items) { item in
                    HistoryRow(
                        title: item.title.isEmpty ? Conversation.untitled : item.title,
                        active: item.id == manager.selectedID,
                        select: { manager.select(id: item.id) },
                        delete: { manager.delete(id: item.id) }
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(chrome)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.color.surfaceStroke)
                .frame(width: 1)
        }
    }

    /// Acrylic chrome with a solid fallback for Reduce Transparency.
    @ViewBuilder private var chrome: some View {
        if reduceTransparency {
            Theme.color.surface
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Theme.color.surface.opacity(0.55)
            }
        }
    }

    private var newChatButton: some View {
        Button {
            Self.logger.info("New chat tapped")
            manager.newChat()
        } label: {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                Text("New chat")
                    .font(Theme.font.headline)
            }
            .foregroundStyle(.white)
            .padding(.vertical, Theme.spacing.md)
            .padding(.horizontal, Theme.spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.accent)
            )
        }
        .buttonStyle(Local402PressableStyle())
        .keyboardShortcut("n", modifiers: .command)
        .help("New chat")
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.font.caption)
            .tracking(0.6)
            .foregroundStyle(Theme.color.textTertiary)
            .padding(.leading, Theme.spacing.xs)
    }
}

/// A ~44pt conversation row with hover highlight. The active row gets an
/// acrylic surface and a 3pt leading accent bar. Right-click reveals a delete
/// action so the resting visual stays clean.
private struct HistoryRow: View {
    let title: String
    let active: Bool
    let select: () -> Void
    let delete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 16))
                    .foregroundStyle(active ? Theme.color.textPrimary : Theme.color.textSecondary)
                Text(title)
                    .font(Theme.font.callout)
                    .foregroundStyle(active ? Theme.color.textPrimary : Theme.color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground)
            .overlay(alignment: .leading) {
                if active {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Theme.color.accent)
                        .frame(width: 3)
                        .padding(.vertical, Theme.spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder private var rowBackground: some View {
        if active {
            Color.clear.local402Acrylic(cornerRadius: Theme.radius.md, appears: false)
        } else {
            RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                .fill(hovering ? Theme.color.surfaceElevated.opacity(0.7) : Color.clear)
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        Local402HistorySidebar()
            .environment(AppState())
            .frame(width: 280)
    }
    .frame(width: 280, height: 600)
    .preferredColorScheme(.dark)
}
