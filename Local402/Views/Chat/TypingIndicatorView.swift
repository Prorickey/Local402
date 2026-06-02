//
//  TypingIndicatorView.swift
//  Local402
//
//  Animated three-dot indicator shown while the agent is "thinking".
//

import SwiftUI

struct TypingIndicatorView: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.color.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(opacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .accessibilityLabel("Agent is typing")
    }

    private func opacity(for index: Int) -> Double {
        let base = 0.3
        let shift = Double(index) * 0.2
        return base + (1 - base) * abs(sin((phase + shift) * .pi))
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
