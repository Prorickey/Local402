//
//  TypingIndicatorView.swift
//  Local402
//
//  Animated three-dot "thinking" indicator shown before the first token.
//  Renders the Copilot-style flourish pulse: three dots filled with the blue
//  brand gradient, staggered, gated on Reduce Motion. See DESIGN.md §4.
//

import SwiftUI

struct TypingIndicatorView: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(LinearGradient.local402Flourish)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Local402 is thinking")
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        TypingIndicatorView()
            .padding(Theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .fill(Theme.color.surface)
            )
            .padding(Theme.spacing.xl)
    }
    .frame(width: 240, height: 160)
    .preferredColorScheme(.dark)
}
