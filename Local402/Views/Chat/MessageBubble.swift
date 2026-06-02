//
//  MessageBubble.swift
//  Local402
//
//  A single chat turn. Assistant turns render as a Copilot-style "answer card"
//  (flourish mark, ordered text/payment segments, a per-answer spend chip, and
//  a hover-revealed action row); user turns render as an asymmetric blue bubble.
//  See DESIGN.md §3–§4.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    static let maxAnswerWidth: CGFloat = 720
    private static let maxUserWidth: CGFloat = 560

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: Theme.spacing.xs) {
            if isUser {
                userTurn
            } else {
                AssistantAnswerCard(message: message)
            }

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .padding(.horizontal, Theme.spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - User turn (asymmetric bubble)

    private var userTurn: some View {
        HStack {
            Spacer(minLength: Theme.spacing.xxl)
            Text(plainText)
                .font(Theme.font.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.spacing.md)
                .padding(.horizontal, Theme.spacing.lg)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.radius.lg,
                        bottomLeadingRadius: Theme.radius.lg,
                        bottomTrailingRadius: Theme.radius.sm,
                        topTrailingRadius: Theme.radius.lg,
                        style: .continuous
                    )
                    .fill(Theme.color.userBubble)
                )
                .frame(maxWidth: Self.maxUserWidth, alignment: .trailing)
        }
    }

    /// Flattened text of a (plain-text) user message.
    private var plainText: String {
        message.segments.reduce(into: "") { result, segment in
            if case .text(let value) = segment { result += value }
        }
    }
}

// MARK: - Assistant answer card

private struct AssistantAnswerCard: View {
    let message: ChatMessage

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            HStack(alignment: .top, spacing: Theme.spacing.md) {
                Local402Flourish(size: 22)

                VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                    segmentBody(for: message.segments)

                    if showsTypingIndicator {
                        TypingIndicatorView()
                            .padding(.vertical, Theme.spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !message.isStreaming {
                actionRow
            }
        }
        .padding(Theme.spacing.lg)
        .frame(maxWidth: MessageBubble.maxAnswerWidth, alignment: .leading)
        .local402Acrylic(cornerRadius: Theme.radius.lg)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local402 response")
    }

    // MARK: Segment body

    @ViewBuilder
    private func segmentBody(for segments: [MessageSegment]) -> some View {
        ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
            switch segment {
            case .text(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if isLastTextWhileStreaming(at: index) {
                        Local402StreamingText(text: value)
                    } else {
                        Text(value)
                            .font(Theme.font.body)
                            .foregroundStyle(Theme.color.textPrimary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            case .payment(let event):
                PaymentInlineView(event: event)
            }
        }
    }

    /// The trailing text segment gets the streaming shimmer while the message streams.
    private func isLastTextWhileStreaming(at index: Int) -> Bool {
        guard message.isStreaming else { return false }
        let lastTextIndex = message.segments.lastIndex {
            if case .text = $0 { return true } else { return false }
        }
        return index == lastTextIndex
    }

    // MARK: Action row + spend chip

    private var actionRow: some View {
        HStack(spacing: Theme.spacing.lg) {
            if spentOnAnswer > 0 { spendChip }
            Spacer(minLength: 0)
            Group {
                actionIcon("doc.on.doc", help: "Copy")
                actionIcon("arrow.clockwise", help: "Regenerate")
                actionIcon("hand.thumbsup", help: "Good response")
                actionIcon("hand.thumbsdown", help: "Bad response")
                actionIcon("square.and.arrow.up", help: "Share")
                actionIcon("ellipsis", help: "More")
            }
            .opacity(hovering ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .padding(.leading, 34)
    }

    private var spendChip: some View {
        let label = PaymentEvent.currencyFormatter.string(from: spentOnAnswer as NSDecimalNumber) ?? "$0.00"
        return HStack(spacing: Theme.spacing.xs) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Spent \(label) on this answer")
        }
        .paymentPill()
    }

    private func actionIcon(_ name: String, help: String) -> some View {
        Button { } label: {
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundStyle(Theme.color.textSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Derived state

    /// Sum of all payment amounts in this answer.
    private var spentOnAnswer: Decimal {
        message.segments.reduce(into: Decimal(0)) { total, segment in
            if case .payment(let event) = segment { total += event.amount }
        }
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
    .frame(width: 760)
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
    .frame(width: 760)
    .preferredColorScheme(.dark)
}
