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

                content(for: onboarding.coinbase, connect: onboarding.connectCoinbase)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacing.xl)
            .card(padding: Theme.spacing.xl, fill: Theme.color.surface)
            .animation(.easeInOut(duration: 0.25), value: onboarding.coinbase)
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
            disconnected(connect: connect)
        case .connecting:
            connecting
        case .connected:
            connected
        }
    }

    private func disconnected(connect: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.spacing.lg) {
            VStack(spacing: Theme.spacing.xs) {
                Text("Connect your Coinbase account")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
                Text("Local402 provisions a Coinbase wallet your agents use to pay per request. x402 payments settle through Coinbase, and no funds move until you approve them.")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: "Connect Coinbase", systemImage: "link", action: connect)
        }
    }

    private var connecting: some View {
        VStack(spacing: Theme.spacing.md) {
            SpinnerView(size: 24, lineWidth: 3)
            Text("Connecting to Coinbase…")
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)

            PrimaryButton(title: "Connecting…", isEnabled: false) {}
        }
    }

    private var connected: some View {
        VStack(spacing: Theme.spacing.lg) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.color.paymentGreen)
                Text("Connected")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.paymentGreen)
            }
            .transition(.scale.combined(with: .opacity))

            VStack(spacing: Theme.spacing.sm) {
                accountRow(label: "Account", value: "agent@local402.dev", systemImage: "person.circle")
                Divider().overlay(Theme.color.surfaceStroke)
                accountRow(label: "Agent wallet", value: "Coinbase · USDC", systemImage: "wallet.pass")
            }
            .padding(Theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
        }
    }

    private func accountRow(label: String, value: String, systemImage: String) -> some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.textTertiary)
            Text(label)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textPrimary)
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
    state.onboarding.coinbase = .connected
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
