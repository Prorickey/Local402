//
//  AppStyles.swift
//  Local402
//
//  Reusable button styles and view modifiers built on the Theme tokens.
//

import SwiftUI

// MARK: - Card container

/// Rounded surface container with a hairline stroke.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.spacing.lg
    var fill: Color = Theme.color.surface

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .stroke(Theme.color.surfaceStroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = Theme.spacing.lg, fill: Color = Theme.color.surface) -> some View {
        modifier(CardModifier(padding: padding, fill: fill))
    }
}

// MARK: - Accent button style

/// Primary call-to-action button: filled accent, hover/press feedback.
struct AccentButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font.headline)
            .foregroundStyle(.white)
            .padding(.vertical, Theme.spacing.md)
            .padding(.horizontal, Theme.spacing.xl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }

    private func backgroundColor(pressed: Bool) -> Color {
        if pressed { return Theme.color.accent.opacity(0.85) }
        return hovering ? Theme.color.accentHover : Theme.color.accent
    }
}

/// Secondary button: subtle surface fill, used for "Back"/"Skip" actions.
struct SecondaryButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font.callout)
            .foregroundStyle(Theme.color.textSecondary)
            .padding(.vertical, Theme.spacing.md)
            .padding(.horizontal, Theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(hovering ? Theme.color.surfaceElevated : Theme.color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .stroke(Theme.color.surfaceStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

// MARK: - Payment pill

/// Green translucent pill used for inline payment events.
struct PaymentPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.font.callout)
            .foregroundStyle(Theme.color.paymentGreen)
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.md)
            .background(
                Capsule().fill(Theme.color.paymentGreenSoft)
            )
            .overlay(
                Capsule().stroke(Theme.color.paymentGreen.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    func paymentPill() -> some View {
        modifier(PaymentPillModifier())
    }
}
