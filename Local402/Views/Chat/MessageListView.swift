//
//  MessageListView.swift
//  Local402
//
//  Scrollable column of message bubbles that auto-scrolls to the newest
//  content as messages arrive and as the streaming reply grows.
//

import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    /// Status shown by the streaming bubble while the model loads (download/load).
    var loadingText: String? = nil
    var loadingProgress: Double? = nil

    private static let bottomAnchor = "bottom"

    /// Readable measure for the centered conversation column.
    private static let readableWidth: CGFloat = 760

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.spacing.xl) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            loadingText: message.isStreaming ? loadingText : nil,
                            loadingProgress: message.isStreaming ? loadingProgress : nil
                        )
                        .id(message.id)
                    }

                    // Invisible anchor pinned to the bottom for auto-scroll.
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .frame(maxWidth: Self.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.spacing.xl)
                .padding(.vertical, Theme.spacing.xxl)
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: lastSegmentCount) {
                scrollToBottom(proxy)
            }
            .onChange(of: lastMessageLength) {
                scrollToBottom(proxy)
            }
            .onAppear {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    /// Segment count of the last message — changes while a reply streams in.
    private var lastSegmentCount: Int {
        messages.last?.segments.count ?? 0
    }

    /// Total text length of the last message — grows token-by-token while
    /// streaming, so auto-scroll follows the live reply.
    private var lastMessageLength: Int {
        guard let last = messages.last else { return 0 }
        return last.segments.reduce(0) { sum, segment in
            if case .text(let value) = segment { return sum + value.count }
            return sum + 1
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }
}

#Preview {
    let now = Date()
    let messages: [ChatMessage] = [
        ChatMessage.text(
            "I'm running locally with your company files loaded for context.",
            role: .assistant,
            timestamp: now.addingTimeInterval(-300)
        ),
        ChatMessage.text(
            "What's the latest on Q3 revenue?",
            role: .user,
            timestamp: now.addingTimeInterval(-200)
        ),
        ChatMessage(
            role: .assistant,
            segments: [
                .text("Let me check current sources for that. "),
                .payment(PaymentEvent(
                    amount: 0.02,
                    label: "Web search",
                    resource: "api.exa.ai/search",
                    timestamp: now.addingTimeInterval(-180)
                )),
                .text("Based on three recent results, the trend is clearly upward this quarter.")
            ],
            timestamp: now.addingTimeInterval(-180)
        ),
        ChatMessage.text(
            "Thanks — that's exactly what I needed.",
            role: .user,
            timestamp: now
        )
    ]

    return ZStack {
        Theme.color.background.ignoresSafeArea()
        MessageListView(messages: messages)
    }
    .frame(width: 640, height: 500)
    .preferredColorScheme(.dark)
}
