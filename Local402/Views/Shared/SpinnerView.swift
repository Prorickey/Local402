//
//  SpinnerView.swift
//  Local402
//
//  A themed indeterminate spinner used during simulated async work.
//

import SwiftUI

struct SpinnerView: View {
    var size: CGFloat = 18
    var lineWidth: CGFloat = 2.5
    var tint: Color = Theme.color.accent

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 0.9).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        SpinnerView(size: 32)
            .padding(Theme.spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .fill(Theme.color.surface)
            )
    }
    .frame(width: 200, height: 200)
    .preferredColorScheme(.dark)
}
