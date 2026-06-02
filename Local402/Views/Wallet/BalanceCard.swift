//
//  BalanceCard.swift
//  Local402
//
//  Prominent wallet balance card: large balance figure, total spent, a
//  compact "Add funds" affordance, and a Coinbase connection status pill.
//

import SwiftUI
import os

struct BalanceCard: View {
    let wallet: WalletInfo
    let totalSpentLabel: String

    private static let logger = Logger(subsystem: "Local402", category: "BalanceCard")

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.lg) {
            header
            balance
            Divider()
                .overlay(Theme.color.surfaceStroke)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Theme.spacing.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
    }

    // MARK: - Sections

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
                    .fill(Theme.color.accent)
            )
        }
        .buttonStyle(.plain)
        .help("Add funds to your wallet")
    }

    // MARK: - Derived values

    private var amountString: String {
        WalletInfo.balanceFormatter.string(from: wallet.balance as NSDecimalNumber) ?? "0.00"
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Theme.color.accent.opacity(0.55),
                Theme.color.surfaceStroke.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
