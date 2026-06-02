//
//  OnboardingCompleteView.swift
//  Local402
//
//  Final success splash: celebratory mark, a short recap of the user's
//  choices, and the entry point into the main app.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(AppState.self) private var appState

    @State private var appeared = false

    var body: some View {
        let onboarding = appState.onboarding

        VStack(spacing: Theme.spacing.xl) {
            celebrationMark
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: Theme.spacing.sm) {
                Text(OnboardingStep.complete.title)
                    .font(Theme.font.largeTitle)
                    .foregroundStyle(Theme.color.textPrimary)
                Text(OnboardingStep.complete.subtitle)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            recap(onboarding: onboarding)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            PrimaryButton(title: "Enter Local402", systemImage: "arrow.right") {
                appState.completeOnboarding()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    // MARK: - Celebration mark

    private var celebrationMark: some View {
        ZStack {
            Circle()
                .fill(Theme.color.paymentGreenSoft)
                .frame(width: 96, height: 96)
            Circle()
                .stroke(Theme.color.paymentGreen.opacity(0.4), lineWidth: 1)
                .frame(width: 96, height: 96)
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.color.paymentGreen)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(Theme.color.accentHover)
                .offset(x: 6, y: -2)
        }
    }

    // MARK: - Recap

    private func recap(onboarding: OnboardingState) -> some View {
        VStack(spacing: Theme.spacing.sm) {
            recapRow(
                systemImage: "cpu",
                label: "Model",
                value: onboarding.selectedModel?.name ?? "—"
            )
            Divider().overlay(Theme.color.surfaceStroke)
            recapRow(
                systemImage: "doc.on.doc",
                label: "Context files",
                value: "\(onboarding.files.count)"
            )
            Divider().overlay(Theme.color.surfaceStroke)
            recapRow(
                systemImage: "wallet.pass",
                label: "Funded",
                value: fundedLabel(onboarding.fundingAmount)
            )
        }
        .padding(Theme.spacing.lg)
        .card(fill: Theme.color.surface)
    }

    private func recapRow(systemImage: String, label: String, value: String) -> some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.textTertiary)
                .frame(width: 18)
            Text(label)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textPrimary)
                .monospacedDigit()
        }
    }

    private func fundedLabel(_ amount: Decimal) -> String {
        let value = (amount as NSDecimalNumber).doubleValue
        return String(format: "$%.2f USDC", value)
    }
}

#Preview {
    let state = AppState()
    state.onboarding.selectedModel = MockModels.all[0]
    return ZStack {
        Theme.color.backgroundGradient.ignoresSafeArea()
        OnboardingCompleteView()
            .frame(maxWidth: 560)
            .padding(Theme.spacing.xxl)
    }
    .environment(state)
    .frame(width: 640, height: 720)
    .preferredColorScheme(.dark)
}
