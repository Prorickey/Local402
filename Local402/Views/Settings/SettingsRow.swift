//
//  SettingsRow.swift
//  Local402
//
//  A reusable labeled settings row: optional icon + title + subtitle on the
//  left, arbitrary trailing content on the right.
//

import SwiftUI

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                            .fill(Theme.color.surfaceElevated)
                    )
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
        .padding(.vertical, Theme.spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Convenience: plain value row

extension SettingsRow where Trailing == Text {
    /// A row whose trailing content is a simple secondary value string.
    init(title: String, subtitle: String? = nil, systemImage: String? = nil, value: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
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
                    systemImage: "creditcard"
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
