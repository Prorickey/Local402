//
//  MessageBubble.swift
//  Local402
//
//  A single chat message rendered as a left- or right-aligned bubble.
//  Renders ordered text/payment segments. While the assistant is replying it
//  shows a live state: a model download/load status before generation starts,
//  then a blinking cursor on the last line as tokens stream in.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    /// While this message is streaming and the model isn't generating yet, a
    /// short status line (e.g. "Downloading Qwen2.5 1.5B…") shown by the dots.
    var loadingText: String? = nil
    /// Download progress (0...1) for a determinate bar; nil = indeterminate.
    var loadingProgress: Double? = nil

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

                if !isUser && !message.citations.isEmpty {
                    citationsFooter
                }

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
                switch row.kind {
                case .text(let value):
                    StreamingTextRow(
                        text: value,
                        showsCursor: message.isStreaming && row.id == lastTextRowID
                    )
                case .payment(let event):
                    PaymentInlineView(event: event)
                }
            }

            if showsWaitingState {
                waitingState
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

    // MARK: - Citations

    /// One chip per unique (document, page) the model retrieved while answering.
    private var citationsFooter: some View {
        var seen = Set<String>()
        let unique = message.citations.filter { seen.insert($0.label).inserted }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing.xs) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.color.textTertiary)

                ForEach(unique) { citation in
                    Text(citation.label)
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, Theme.spacing.sm)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.color.surfaceElevated))
                        .overlay(Capsule().stroke(Theme.color.surfaceStroke, lineWidth: 1))
                }
            }
            .padding(.horizontal, Theme.spacing.xs)
        }
        .accessibilityLabel("Sources: \(unique.map(\.label).joined(separator: ", "))")
    }

    /// The "thinking"/loading state: animated dots, plus a model download/load
    /// status line and progress bar when the model isn't ready yet.
    private var waitingState: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            HStack(spacing: Theme.spacing.sm) {
                TypingIndicatorView()
                if let loadingText {
                    Text(loadingText)
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textSecondary)
                }
            }

            if let loadingProgress {
                ProgressView(value: min(max(loadingProgress, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(Theme.color.accent)
                    .frame(maxWidth: 220)
            }
        }
        .padding(.vertical, Theme.spacing.xs)
    }

    /// `true` when streaming has started but no visible text/payment exists yet.
    private var showsWaitingState: Bool {
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

    private enum RowKind {
        case text(String)
        case payment(PaymentEvent)
    }

    private struct Row: Identifiable {
        let id: String
        let kind: RowKind
    }

    /// id of the final text row — the one that carries the streaming cursor.
    private var lastTextRowID: String? {
        rows.last { if case .text = $0.kind { return true } else { return false } }?.id
    }

    /// Groups consecutive text segments into paragraphs; each payment is its own row.
    private var rows: [Row] {
        var result: [Row] = []
        var paragraph = ""

        func flushParagraph(index: Int) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            paragraph = ""
            guard !trimmed.isEmpty else { return }
            result.append(Row(id: "text-\(index)", kind: .text(trimmed)))
        }

        for (index, segment) in message.segments.enumerated() {
            switch segment {
            case .text(let value):
                paragraph += value
            case .payment(let event):
                flushParagraph(index: index)
                result.append(Row(id: "payment-\(event.id.uuidString)", kind: .payment(event)))
            }
        }
        flushParagraph(index: message.segments.count)

        return result
    }
}

// MARK: - Streaming text + cursor

/// A paragraph of streamed text. When `showsCursor` is true, a block cursor
/// blinks at the end of the text to signal active token generation. The cursor
/// glyph always occupies space (it blinks via color) so the text never reflows.
private struct StreamingTextRow: View {
    let text: String
    let showsCursor: Bool

    var body: some View {
        if showsCursor {
            TimelineView(.periodic(from: .now, by: 0.55)) { context in
                let on = Int(context.date.timeIntervalSinceReferenceDate / 0.55) % 2 == 0
                (Text(text) + Text("▍").foregroundColor(on ? Theme.color.accent : .clear))
                    .font(Theme.font.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(text)
                .font(Theme.font.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
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
    .frame(width: 640)
    .preferredColorScheme(.dark)
}

#Preview("Streaming text") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        MessageBubble(
            message: ChatMessage(
                role: .assistant,
                segments: [.text("Based on your handbook, carryover is capped at 20 days")],
                timestamp: Date(),
                isStreaming: true
            )
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 640)
    .preferredColorScheme(.dark)
}

#Preview("Downloading model") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        MessageBubble(
            message: ChatMessage(role: .assistant, segments: [], timestamp: Date(), isStreaming: true),
            loadingText: "Downloading Qwen2.5 1.5B…",
            loadingProgress: 0.42
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 640)
    .preferredColorScheme(.dark)
}
