//
//  CoinbaseAuthStepView.swift
//  Local402
//
//  Step C-1: simulated Coinbase connection. The logo mark is fabricated (no
//  real Coinbase asset) and the connection is entirely simulated.
//

import SwiftUI

struct CoinbaseAuthStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let onboarding = appState.onboarding

        VStack(alignment: .leading, spacing: Theme.spacing.xl) {
            OnboardingStepHeader(step: .coinbase)

            VStack(spacing: Theme.spacing.lg) {
                CoinbaseLogoMark()
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.color.accent.opacity(0.35), radius: 12, y: 2)

                content(for: onboarding.coinbase, connect: onboarding.connectCoinbase)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacing.xl)
            .local402Acrylic(cornerRadius: Theme.radius.lg, appears: false)
            .shadow(color: .black.opacity(0.22), radius: 10, y: 2)
            .animation(.easeInOut(duration: 0.25), value: onboarding.coinbase)
        }
        .onAppear {
            // Agentic Wallet: provision the agent wallet automatically on entry
            // (CDP getOrCreateAccount on the BFF) — no login, no button tap.
            if case .disconnected = onboarding.coinbase {
                onboarding.connectCoinbase()
            }
        }
    }

    // MARK: - State-driven content

    @ViewBuilder
    private func content(
        for state: CoinbaseConnectionState,
        connect: @escaping () -> Void
    ) -> some View {
        switch state {
        case .disconnected:
            preparing
        case .creating:
            creating
        case .connected(let address):
            connected(address: address)
        case .failed(let message):
            failed(message: message, retry: connect)
        }
    }

    /// Shown the instant the step appears, before `connectCoinbase()` flips the
    /// state to `.creating`. The wallet is provisioned automatically — there is
    /// no button to tap.
    private var preparing: some View {
        VStack(spacing: Theme.spacing.lg) {
            VStack(spacing: Theme.spacing.xs) {
                Text("Setting up your Coinbase wallet")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
                Text("Local402 provisions a Coinbase agent wallet for you automatically — no login required. x402 payments settle through Coinbase, and no funds move until you approve them.")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SpinnerView(size: 24, lineWidth: 3)
        }
    }

    private var creating: some View {
        VStack(spacing: Theme.spacing.md) {
            SpinnerView(size: 24, lineWidth: 3)
            Text("Setting up your wallet…")
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)

            PrimaryButton(title: "Setting up…", isEnabled: false) {}
        }
    }

    private func connected(address: String) -> some View {
        VStack(spacing: Theme.spacing.lg) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.color.paymentGreen)
                Text("Wallet ready")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.paymentGreen)
            }
            .transition(.scale.combined(with: .opacity))

            VStack(spacing: Theme.spacing.sm) {
                accountRow(label: "Address", value: truncatedAddress(address), systemImage: "number", mono: true)
                Divider().overlay(Theme.color.surfaceStroke)
                accountRow(label: "Agent wallet", value: "Coinbase · USDC", systemImage: "wallet.pass")
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

    private func failed(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.spacing.md) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.color.textSecondary)
                Text("Couldn't set up your wallet")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
            }
            Text(message)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Try again", systemImage: "arrow.clockwise", action: retry)
        }
    }

    private func truncatedAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    private func accountRow(label: String, value: String, systemImage: String, mono: Bool = false) -> some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.textTertiary)
            Text(label)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? Theme.font.mono : Theme.font.callout)
                .foregroundStyle(Theme.color.textPrimary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Fabricated logo mark

/// A fabricated Coinbase-style mark: a blue disc with a centered square ring.
/// Not an official asset.
private struct CoinbaseLogoMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Theme.color.accent)
                RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                    .stroke(.white, lineWidth: side * 0.1)
                    .frame(width: side * 0.42, height: side * 0.42)
            }
            .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Disconnected") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            CoinbaseAuthStepView()
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(AppState())
    .frame(width: 640, height: 640)
    .preferredColorScheme(.dark)
}

#Preview("Connected") {
    let state = AppState()
    state.onboarding.coinbase = .connected(address: "0x7a3f4b2e9d1c8f5a6b0e2d4c9f1a8b3e7c0d6f21")
    return ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            CoinbaseAuthStepView()
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(state)
    .frame(width: 640, height: 640)
    .preferredColorScheme(.dark)
}

#Preview("Failed") {
    let state = AppState()
    state.onboarding.coinbase = .failed("Network error: the BFF is unreachable.")
    return ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            CoinbaseAuthStepView()
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(state)
    .frame(width: 640, height: 640)
    .preferredColorScheme(.dark)
}
