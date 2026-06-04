//
//  Local402StreamingText.swift
//  Local402
//
//  Assistant body text with a low-opacity blue "flourish" shimmer sweeping
//  across while streaming. The cosmetic sweep yields to Reduce Motion; token
//  streaming itself is unaffected. See DESIGN.md §4.
//

import SwiftUI

struct Local402StreamingText: View {
    let text: String

    @State private var phase: CGFloat = -0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Local402Markdown(text: text)
            .overlay(shimmer)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }

    @ViewBuilder private var shimmer: some View {
        if !reduceMotion {
            LinearGradient(
                colors: [.clear,
                         Theme.color.accentHover.opacity(0.28),
                         Theme.color.accent.opacity(0.18),
                         .clear],
                startPoint: .init(x: phase, y: 0.5),
                endPoint: .init(x: phase + 0.3, y: 0.5)
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        Local402StreamingText(text: "Streaming a response with a soft blue shimmer sweeping across the text as tokens arrive.")
            .frame(maxWidth: 480)
            .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 200)
    .preferredColorScheme(.dark)
}
