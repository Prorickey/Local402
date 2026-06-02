//
//  WalletFundingStepView.swift
//  Local402
//
//  Step C-2: choose a starting balance and run a simulated on-chain funding
//  transaction. The balance itself is applied later by completeOnboarding().
//

import SwiftUI
import os

struct WalletFundingStepView: View {
    @Environment(AppState.self) private var appState
    @Bindable var onboarding: OnboardingState

    @FocusState private var amountFocused: Bool

    private static let quickPicks: [Decimal] = [10, 25, 50, 100]

    init(onboarding: OnboardingState) {
        self.onboarding = onboarding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xl) {
            OnboardingStepHeader(step: .funding)

            VStack(spacing: Theme.spacing.lg) {
                content(for: onboarding.funding)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacing.xl)
            .local402Acrylic(cornerRadius: Theme.radius.lg, appears: false)
            .shadow(color: .black.opacity(0.22), radius: 10, y: 2)
            .animation(.easeInOut(duration: 0.25), value: onboarding.funding)
        }
    }

    // MARK: - State-driven content

    @ViewBuilder
    private func content(for state: FundingState) -> some View {
        switch state {
        case .idle:
            idle
        case .confirming:
            confirming
        case .funded(let txHash):
            funded(txHash: txHash)
        }
    }

    // MARK: - Idle (amount entry)

    private var idle: some View {
        VStack(spacing: Theme.spacing.lg) {
            amountField
            quickPicks
            PrimaryButton(
                title: "Fund wallet",
                systemImage: "bolt.fill",
                isEnabled: canFund,
                action: onboarding.fundWallet
            )
            if onboarding.coinbase != .connected {
                Text("Connect Coinbase first to fund your wallet.")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }
        }
    }

    private var amountField: some View {
        VStack(spacing: Theme.spacing.xs) {
            Text("Starting balance")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .tracking(0.6)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.xs) {
                Text("$")
                    .font(Theme.font.title)
                    .foregroundStyle(Theme.color.textSecondary)
                TextField("0", value: $onboarding.fundingAmount, format: .number)
                    .textFieldStyle(.plain)
                    .font(Theme.font.largeTitle)
                    .foregroundStyle(Theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .monospacedDigit()
                    .focused($amountFocused)
                Text("USDC")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textTertiary)
            }
            .padding(.vertical, Theme.spacing.md)
            .padding(.horizontal, Theme.spacing.xl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .strokeBorder(
                        amountFocused ? Theme.color.accent : Theme.color.surfaceStroke,
                        lineWidth: amountFocused ? 1.5 : 1
                    )
            )
            .animation(.easeOut(duration: 0.18), value: amountFocused)
        }
    }

    private var quickPicks: some View {
        HStack(spacing: Theme.spacing.sm) {
            ForEach(Self.quickPicks, id: \.self) { amount in
                quickPickButton(amount)
            }
        }
    }

    private func quickPickButton(_ amount: Decimal) -> some View {
        let isSelected = onboarding.fundingAmount == amount
        return Button {
            onboarding.fundingAmount = amount
        } label: {
            Text(quickLabel(amount))
                .font(Theme.font.callout)
                .foregroundStyle(isSelected ? .white : Theme.color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.color.accent : Theme.color.surfaceElevated)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Theme.color.accent : Theme.color.surfaceStroke, lineWidth: 1)
                )
        }
        .buttonStyle(Local402PressableStyle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .help("Set starting balance to \(quickLabel(amount))")
    }

    // MARK: - Confirming

    private var confirming: some View {
        VStack(spacing: Theme.spacing.md) {
            SpinnerView(size: 24, lineWidth: 3)
            Text("Adding USDC to your Coinbase wallet…")
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
            Text(amountLabel)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Funded

    private func funded(txHash: String) -> some View {
        VStack(spacing: Theme.spacing.lg) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.color.paymentGreen)
                Text("Funded \(amountLabel)")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.paymentGreen)
            }
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.lg)
            .background(Capsule().fill(Theme.color.paymentGreenSoft))
            .overlay(Capsule().strokeBorder(Theme.color.paymentGreen.opacity(0.3), lineWidth: 1))
            .transition(.scale.combined(with: .opacity))

            Text("Settled via Coinbase")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)

            VStack(spacing: Theme.spacing.sm) {
                HStack {
                    Text("Tx hash")
                        .font(Theme.font.callout)
                        .foregroundStyle(Theme.color.textSecondary)
                    Spacer()
                    Text(truncatedHash(txHash))
                        .font(Theme.font.mono)
                        .foregroundStyle(Theme.color.textPrimary)
                        .textSelection(.enabled)
                }
                Divider().overlay(Theme.color.surfaceStroke)
                Button {
                    Self.logger.info("View on explorer tapped (no-op)")
                } label: {
                    HStack(spacing: Theme.spacing.xs) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View on explorer")
                    }
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.accentHover)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .strokeBorder(Theme.color.surfaceStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Derived values

    private var canFund: Bool {
        onboarding.coinbase == .connected && onboarding.fundingAmount > 0
    }

    private var amountLabel: String {
        let value = (onboarding.fundingAmount as NSDecimalNumber).doubleValue
        return String(format: "$%.2f USDC", value)
    }

    private func quickLabel(_ amount: Decimal) -> String {
        "$\((amount as NSDecimalNumber).intValue)"
    }

    private func truncatedHash(_ hash: String) -> String {
        guard hash.count > 14 else { return hash }
        let prefix = hash.prefix(8)
        let suffix = hash.suffix(6)
        return "\(prefix)…\(suffix)"
    }

    private static let logger = Logger(subsystem: "Local402", category: "WalletFunding")
}

#Preview {
    let state = AppState()
    state.onboarding.coinbase = .connected
    return ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            WalletFundingStepView(onboarding: state.onboarding)
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(state)
    .frame(width: 640, height: 720)
    .preferredColorScheme(.dark)
}
