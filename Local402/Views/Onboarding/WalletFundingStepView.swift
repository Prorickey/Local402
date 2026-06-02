//
//  WalletFundingStepView.swift
//  Local402
//
//  Step C-2: choose a starting balance and run a simulated on-chain funding
//  transaction. The balance itself is applied later by completeOnboarding().
//

import SwiftUI
import PassKit
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
        case .presentingApplePay:
            settling(message: "Confirm payment in Apple Pay…")
        case .settling:
            settling(message: "Adding USDC to your Coinbase wallet…")
        case .funded(let txHash):
            funded(txHash: txHash)
        case .failed(let message):
            failed(message: message)
        }
    }

    // MARK: - Idle (amount entry)

    private var idle: some View {
        VStack(spacing: Theme.spacing.lg) {
            amountField
            quickPicks
            fundButton
            if !walletConnected {
                Text("Set up your Coinbase wallet first to fund it.")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }
        }
    }

    /// Native Apple Pay button only when fully live; the styled button is used in
    /// demo mode and when Apple Pay is simulated (no Merchant ID yet).
    @ViewBuilder
    private var fundButton: some View {
        if CoinbaseConfig.demoMode || CoinbaseConfig.simulateApplePay {
            PrimaryButton(
                title: "Fund with Apple Pay",
                systemImage: "apple.logo",
                isEnabled: canFund,
                action: onboarding.fundWallet
            )
        } else {
            ApplePayButton(action: onboarding.fundWallet)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .opacity(canFund && applePayAvailable ? 1 : 0.4)
                .allowsHitTesting(canFund && applePayAvailable)
                .help(applePayAvailable ? "Pay with Apple Pay" : "Apple Pay isn't available on this device.")
            if !applePayAvailable {
                Text("Apple Pay isn't available on this device.")
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

    // MARK: - In-flight (Apple Pay / settling)

    private func settling(message: String) -> some View {
        VStack(spacing: Theme.spacing.md) {
            SpinnerView(size: 24, lineWidth: 3)
            Text(message)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)
            Text(amountLabel)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Failed

    private func failed(message: String) -> some View {
        VStack(spacing: Theme.spacing.md) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.color.textSecondary)
                Text("Funding didn't go through")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
            }
            Text(message)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                onboarding.resetFunding()
            }
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

    private var walletConnected: Bool {
        if case .connected = onboarding.coinbase { return true }
        return false
    }

    private var applePayAvailable: Bool {
        ApplePayFundingController.canMakePayments()
    }

    private var canFund: Bool {
        walletConnected && onboarding.fundingAmount > 0
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

// MARK: - Native Apple Pay button (macOS)

/// Wraps the native `PKPaymentButton` so SwiftUI can present the system Apple
/// Pay button. The actual sheet is driven by `ApplePayFundingController`.
private struct ApplePayButton: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .automatic)
        button.target = context.coordinator
        button.action = #selector(Coordinator.tapped)
        return button
    }

    func updateNSView(_ nsView: PKPaymentButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

#Preview {
    let state = AppState()
    state.onboarding.coinbase = .connected(address: "0x7a3f4b2e9d1c8f5a6b0e2d4c9f1a8b3e7c0d6f21")
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
