//
//  BalanceCard.swift
//  Local402
//
//  Prominent wallet balance hero card with Fluent acrylic surface: a thin
//  "value" accent strip, a large hero balance figure, the green Coinbase
//  connection pill, a total-spent row, and an "Add funds" affordance whose
//  fill uses the local402Value money gradient. See DESIGN.md.
//

import SwiftUI
import os

struct BalanceCard: View {
    let wallet: WalletInfo
    let totalSpentLabel: String

    @State private var addFundsHovering = false

    private static let logger = Logger(subsystem: "Local402", category: "BalanceCard")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            valueStrip
            VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                header
                balance
                Divider()
                    .overlay(Theme.color.surfaceStroke)
                footer
            }
            .padding(Theme.spacing.xl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .local402Acrylic(cornerRadius: Theme.radius.lg)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
    }

    // MARK: - Sections

    /// Thin top accent strip — a tasteful "money" cue using the value gradient.
    private var valueStrip: some View {
        LinearGradient.local402Value
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Available balance")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)
                .tracking(0.6)
                .textCase(.uppercase)
            Spacer()
            connectionPill
        }
    }

    private var balance: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.sm) {
            Text(amountString)
                .font(Theme.font.largeTitle)
                .foregroundStyle(Theme.color.textPrimary)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(wallet.currency)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textSecondary)
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.spacing.md) {
            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text("Total spent")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                Text(totalSpentLabel)
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.paymentGreen)
                    .monospacedDigit()
            }
            Spacer()
            addFundsButton
        }
    }

    // MARK: - Components

    private var connectionPill: some View {
        HStack(spacing: Theme.spacing.xs) {
            Circle()
                .fill(Theme.color.paymentGreen)
                .frame(width: 6, height: 6)
            Text("Connected to Coinbase")
                .font(Theme.font.caption)
        }
        .foregroundStyle(Theme.color.paymentGreen)
        .padding(.vertical, Theme.spacing.xs)
        .padding(.horizontal, Theme.spacing.sm)
        .background(Capsule().fill(Theme.color.paymentGreenSoft))
        .overlay(Capsule().stroke(Theme.color.paymentGreen.opacity(0.35), lineWidth: 1))
    }

    private var addFundsButton: some View {
        Button {
            Self.logger.info("Add funds tapped (no-op affordance)")
        } label: {
            HStack(spacing: Theme.spacing.xs) {
                Image(systemName: "plus.circle.fill")
                Text("Add funds")
            }
            .font(Theme.font.callout)
            .foregroundStyle(.white)
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(LinearGradient.local402Value)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .strokeBorder(Color.white.opacity(addFundsHovering ? 0.35 : 0), lineWidth: 1)
            )
            .brightness(addFundsHovering ? 0.06 : 0)
        }
        .buttonStyle(Local402PressableStyle())
        .onHover { hovering in
            addFundsHovering = hovering
            if hovering { Self.logger.debug("Add funds hover") }
        }
        .animation(.easeOut(duration: 0.15), value: addFundsHovering)
        .help("Add funds to your wallet")
    }

    // MARK: - Derived values

    private var amountString: String {
        WalletInfo.balanceFormatter.string(from: wallet.balance as NSDecimalNumber) ?? "0.00"
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        BalanceCard(wallet: MockWallet.initialWallet(), totalSpentLabel: "$0.23")
            .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 320)
    .preferredColorScheme(.dark)
}
