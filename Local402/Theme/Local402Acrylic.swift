//
//  Local402Acrylic.swift
//  Local402
//
//  Fluent-style acrylic surface: frosted material + faint navy tint + hairline
//  + a soft blur-in on appear. Honors Reduce Transparency and Reduce Motion.
//  See DESIGN.md §3.
//

import SwiftUI

struct Local402Acrylic: ViewModifier {
    var cornerRadius: CGFloat = Theme.radius.lg
    var appears: Bool = true

    @State private var shown = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.color.surfaceStroke.opacity(0.8), lineWidth: 1)
            )
            .opacity(shown || !appears ? 1 : 0)
            .blur(radius: (shown || !appears || reduceMotion) ? 0 : 8)
            .onAppear {
                guard appears else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.easeOut(duration: 0.22)) { shown = true }
                }
            }
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency {
            Theme.color.surface
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Theme.color.surface.opacity(0.55)
            }
        }
    }
}

extension View {
    /// Applies the Fluent acrylic surface treatment (see DESIGN.md).
    func local402Acrylic(cornerRadius: CGFloat = Theme.radius.lg, appears: Bool = true) -> some View {
        modifier(Local402Acrylic(cornerRadius: cornerRadius, appears: appears))
    }
}
