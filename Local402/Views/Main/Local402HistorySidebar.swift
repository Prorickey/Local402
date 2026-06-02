//
//  Local402HistorySidebar.swift
//  Local402
//
//  The collapsible chat-history sidebar — the one genuinely desktop-Copilot
//  pattern. Acrylic Fluent chrome with a "New chat" accent button and grouped
//  conversation rows. Demo content only (simulated). See DESIGN.md §5.
//

import SwiftUI
import os

/// A single conversation entry in the history sidebar.
private struct HistoryItem: Identifiable {
    let id = UUID()
    let title: String
}

struct Local402HistorySidebar: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let logger = Logger(subsystem: "com.local402.app", category: "HistorySidebar")

    /// Demo conversations grouped by day. Simulated for the design demo.
    private let today: [HistoryItem] = [
        HistoryItem(title: "Q3 revenue analysis"),
        HistoryItem(title: "Refactor onboarding flow"),
        HistoryItem(title: "Summarize handbook"),
        HistoryItem(title: "Competitor pricing scan"),
    ]
    private let yesterday: [HistoryItem] = [
        HistoryItem(title: "Draft launch email"),
        HistoryItem(title: "Debug payment retry"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            newChatButton

            groupLabel("TODAY")
                .padding(.top, Theme.spacing.lg)

            ForEach(Array(today.enumerated()), id: \.element.id) { index, item in
                HistoryRow(title: item.title, active: index == 0)
            }

            groupLabel("YESTERDAY")
                .padding(.top, Theme.spacing.md)

            ForEach(yesterday) { item in
                HistoryRow(title: item.title, active: false)
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
            Self.logger.info("New chat tapped (demo no-op)")
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
/// acrylic surface and a 3pt leading accent bar.
private struct HistoryRow: View {
    let title: String
    let active: Bool

    @State private var hovering = false

    private static let logger = Logger(subsystem: "com.local402.app", category: "HistorySidebar")

    var body: some View {
        Button {
            Self.logger.info("Conversation selected (demo no-op)")
        } label: {
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
            .frame(width: 280)
    }
    .frame(width: 280, height: 600)
    .preferredColorScheme(.dark)
}
