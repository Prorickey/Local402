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

    private static let bottomAnchor = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.spacing.lg) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Invisible anchor pinned to the bottom for auto-scroll.
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(.horizontal, Theme.spacing.xl)
                .padding(.vertical, Theme.spacing.xl)
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: lastSegmentCount) {
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
