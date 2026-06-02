//
//  MessageBubble.swift
//  Local402
//
//  A single chat message rendered as a left- or right-aligned bubble.
//  Renders ordered text/payment segments and a streaming typing indicator.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    private static let maxBubbleWidth: CGFloat = 560

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: Theme.spacing.xxl) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: Theme.spacing.xs) {
                if !isUser {
                    Text("Local402")
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textTertiary)
                }

                bubble

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                    .padding(.horizontal, Theme.spacing.xs)
            }
            .frame(maxWidth: Self.maxBubbleWidth, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: Theme.spacing.xxl) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - Bubble

    private var bubble: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            ForEach(rows) { row in
                row.view
            }

            if showsTypingIndicator {
                TypingIndicatorView()
                    .padding(.vertical, Theme.spacing.xs)
            }
        }
        .padding(.vertical, Theme.spacing.md)
        .padding(.horizontal, Theme.spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                .fill(isUser ? Theme.color.userBubble : Theme.color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                .stroke(Theme.color.surfaceStroke, lineWidth: isUser ? 0 : 1)
        )
        .foregroundStyle(Theme.color.textPrimary)
    }

    /// `true` when streaming has started but no visible text/payment exists yet.
    private var showsTypingIndicator: Bool {
        message.isStreaming && !hasVisibleContent
    }

    private var hasVisibleContent: Bool {
        message.segments.contains { segment in
            switch segment {
            case .text(let value):
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .payment:
                return true
            }
        }
    }

    // MARK: - Row grouping

    /// A renderable row: a paragraph of text or a single payment pill on its own line.
    private struct Row: Identifiable {
        let id: String
        let view: AnyView
    }

    /// Groups consecutive text segments into paragraphs; each payment is its own row.
    private var rows: [Row] {
        var result: [Row] = []
        var paragraph = ""

        func flushParagraph(index: Int) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { paragraph = ""; return }
            result.append(
                Row(
                    id: "text-\(index)",
                    view: AnyView(
                        Text(trimmed)
                            .font(Theme.font.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    )
                )
            )
            paragraph = ""
        }

        for (index, segment) in message.segments.enumerated() {
            switch segment {
            case .text(let value):
                paragraph += value
            case .payment(let event):
                flushParagraph(index: index)
                result.append(
                    Row(
                        id: "payment-\(event.id.uuidString)",
                        view: AnyView(PaymentInlineView(event: event))
                    )
                )
            }
        }
        flushParagraph(index: message.segments.count)

        return result
    }
}

#Preview("Assistant & User") {
    let assistant = ChatMessage(
        role: .assistant,
        segments: [
            .text("Let me check current sources for that. "),
            .payment(PaymentEvent(
                amount: 0.02,
                label: "Web search",
                resource: "api.exa.ai/search",
                timestamp: Date()
            )),
            .text("Based on three recent results, the trend is clearly upward this quarter.")
        ],
        timestamp: Date()
    )
    let user = ChatMessage.text(
        "What's the latest on Q3 revenue?",
        role: .user,
        timestamp: Date()
    )

    return ZStack {
        Theme.color.background.ignoresSafeArea()
        VStack(spacing: Theme.spacing.lg) {
            MessageBubble(message: assistant)
            MessageBubble(message: user)
        }
        .padding(Theme.spacing.xl)
    }
    .frame(width: 640)
    .preferredColorScheme(.dark)
}

#Preview("Streaming") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        MessageBubble(
            message: ChatMessage(
                role: .assistant,
                segments: [],
                timestamp: Date(),
                isStreaming: true
            )
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 640)
    .preferredColorScheme(.dark)
}
