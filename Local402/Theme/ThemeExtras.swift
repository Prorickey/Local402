//
//  ThemeExtras.swift
//  Local402
//
//  Copilot-inspired additions to the Local402 theme: a few extra semantic
//  tokens and the single blue "flourish" brand gradient. See DESIGN.md.
//

import SwiftUI

extension Theme.color {
    /// Pressed/active blue for buttons and selected affordances.
    static let accentPressed = Color(hex: "#2563EB")
    /// Caution (e.g. low balance).
    static let warning = Color(hex: "#F59E0B")
    /// Failure (e.g. declined payment).
    static let error = Color(hex: "#EF4444")
}

extension LinearGradient {
    /// The single brand gesture — on-theme blue flourish.
    /// Used for the assistant mark, streaming edge, and focus emphasis.
    /// Brand, not state.
    static let local402Flourish = LinearGradient(
        colors: [Theme.color.accent, Theme.color.accentHover],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Optional "value" variant for payment / earnings emphasis only.
    static let local402Value = LinearGradient(
        colors: [Theme.color.accent, Theme.color.paymentGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
}
