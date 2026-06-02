//
//  Theme.swift
//  Local402
//
//  Centralized dark-blue design tokens: colors, spacing, radii, typography.
//

import SwiftUI

/// Namespace for the app's design tokens. Use `Theme.color.*`, `Theme.spacing.*`, etc.
enum Theme {

    // MARK: - Colors

    enum color {
        static let background = Color(hex: "#0A0E1A")
        static let surface = Color(hex: "#121A2E")
        static let surfaceElevated = Color(hex: "#1B2640")
        static let surfaceStroke = Color(hex: "#243048")

        static let accent = Color(hex: "#3B82F6")
        static let accentHover = Color(hex: "#60A5FA")

        static let userBubble = Color(hex: "#1E3A8A")

        static let textPrimary = Color(hex: "#E8ECF4")
        static let textSecondary = Color(hex: "#9AA7C2")
        static let textTertiary = Color(hex: "#5C6B8A")

        static let paymentGreen = Color(hex: "#22C55E")
        static let paymentGreenSoft = Color(hex: "#10331F")

        /// Subtle vertical depth gradient used behind primary surfaces.
        static let backgroundGradient = LinearGradient(
            colors: [Color(hex: "#0A0E1A"), Color(hex: "#0D1320")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Spacing

    enum spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radii

    enum radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    enum font {
        static let largeTitle = SwiftUI.Font.system(size: 30, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 14, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 13, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 11, weight: .medium)
        static let mono = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
    }
}
