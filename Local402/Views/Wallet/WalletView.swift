//
//  WalletView.swift
//  Local402
//
//  Full-surface wallet page: balance card, address row, and a scrollable
//  history of recent x402 micropayments.
//

import SwiftUI

struct WalletView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing.xl) {
                Text("Wallet")
                    .font(Theme.font.title)
                    .foregroundStyle(Theme.color.textPrimary)

                BalanceCard(
                    wallet: appState.wallet.wallet,
                    totalSpentLabel: appState.wallet.totalSpentLabel
                )

                WalletAddressRow(
                    address: appState.wallet.wallet.address,
                    shortAddress: appState.wallet.wallet.shortAddress
                )

                recentPayments
            }
            .padding(Theme.spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.color.background)
    }

    // MARK: - Sections

    private var recentPayments: some View {
        SectionCard("Recent payments") {
            let payments = appState.wallet.payments
            if payments.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                        if index > 0 {
                            Divider()
                                .overlay(Theme.color.surfaceStroke)
                                .padding(.vertical, Theme.spacing.xs)
                        }
                        PaymentRow(payment: payment)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing.sm) {
            Image(systemName: "creditcard")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.color.textTertiary)
            Text("No payments yet")
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textSecondary)
            Text("Agent micropayments will appear here as the model uses paid tools.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.xl)
    }
}

#Preview {
    WalletView()
        .environment(AppState())
        .frame(width: 720, height: 640)
        .preferredColorScheme(.dark)
}
