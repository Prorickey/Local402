//
//  SettingsRow.swift
//  Local402
//
//  A reusable labeled settings row: optional accent icon badge + title +
//  subtitle on the left, arbitrary trailing content on the right, an optional
//  tooltip, and a subtle desktop hover highlight.
//

import SwiftUI

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var help: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            if let systemImage {
                iconBadge(systemImage)
            }

            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text(title)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textSecondary)
                }
            }

            Spacer(minLength: Theme.spacing.md)

            trailing()
        }
        .padding(.vertical, Theme.spacing.sm)
        .padding(.horizontal, Theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                .fill(Theme.color.surfaceElevated.opacity(hovering ? 0.5 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .modifier(OptionalHelp(help: help))
    }

    private func iconBadge(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.color.accent)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                    .fill(Theme.color.accent.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                    .strokeBorder(Theme.color.accent.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Optional tooltip

/// Applies `.help(_:)` only when a non-nil string is provided, keeping the
/// modifier list stable for SwiftUI.
private struct OptionalHelp: ViewModifier {
    let help: String?

    func body(content: Content) -> some View {
        if let help {
            content.help(help)
        } else {
            content
        }
    }
}

// MARK: - Convenience: plain value row

extension SettingsRow where Trailing == Text {
    /// A row whose trailing content is a simple secondary value string.
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        help: String? = nil,
        value: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.help = help
        self.trailing = {
            Text(value)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        SectionCard("Wallet") {
            VStack(spacing: Theme.spacing.sm) {
                SettingsRow(
                    title: "Balance",
                    systemImage: "dollarsign.circle",
                    value: "25.00 USDC"
                )
                Divider().overlay(Theme.color.surfaceStroke)
                SettingsRow(
                    title: "Show cost pills",
                    subtitle: "Display inline x402 payment badges in chat",
                    systemImage: "creditcard",
                    help: "Toggle inline payment badges"
                ) {
                    Text("On")
                        .font(Theme.font.callout)
                        .foregroundStyle(Theme.color.paymentGreen)
                }
            }
        }
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560)
    .preferredColorScheme(.dark)
}
