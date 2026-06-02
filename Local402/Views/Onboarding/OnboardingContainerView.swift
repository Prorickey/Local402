//
//  OnboardingContainerView.swift
//  Local402
//
//  Orchestrates the multi-step onboarding flow: brand + progress bar header,
//  an animated step body, and a bottom navigation bar with Back / Skip /
//  Continue. The final `.complete` splash hides the chrome.
//

import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState

    private let columnWidth: CGFloat = 560

    var body: some View {
        let onboarding = appState.onboarding
        let isComplete = onboarding.step == .complete

        ZStack {
            Theme.color.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: Theme.spacing.xl) {
                if !isComplete {
                    header(step: onboarding.step)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    stepBody(for: onboarding.step)
                        .padding(.vertical, Theme.spacing.lg)
                        .transition(stepTransition)
                        .id(onboarding.step)
                }
                .frame(maxHeight: .infinity)

                if !isComplete {
                    navigationBar(onboarding: onboarding)
                }
            }
            .frame(maxWidth: columnWidth)
            .padding(.horizontal, Theme.spacing.xl)
            .padding(.vertical, Theme.spacing.xxl)
            .animation(.easeInOut(duration: 0.3), value: onboarding.step)
        }
    }

    // MARK: - Header

    private func header(step: OnboardingStep) -> some View {
        VStack(spacing: Theme.spacing.lg) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.color.accent)
                Text("Local402")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
            }

            OnboardingProgressBar(current: step)
        }
    }

    // MARK: - Step body

    @ViewBuilder
    private func stepBody(for step: OnboardingStep) -> some View {
        switch step {
        case .model:
            ModelSelectionStepView()
        case .data:
            DataDropStepView()
        case .coinbase:
            CoinbaseAuthStepView()
        case .funding:
            WalletFundingStepView(onboarding: appState.onboarding)
        case .complete:
            OnboardingCompleteView()
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Navigation bar

    private func navigationBar(onboarding: OnboardingState) -> some View {
        HStack(spacing: Theme.spacing.md) {
            if onboarding.step != .model {
                Button("Back", action: onboarding.goBack)
                    .buttonStyle(SecondaryButtonStyle())
                    .transition(.opacity)
            }

            Button("Skip for now") {
                appState.completeOnboarding()
            }
            .buttonStyle(.plain)
            .font(Theme.font.callout)
            .foregroundStyle(Theme.color.textTertiary)

            Spacer()

            PrimaryButton(
                title: continueTitle(for: onboarding.step),
                systemImage: continueIcon(for: onboarding.step),
                isEnabled: onboarding.canContinue,
                action: onboarding.advance
            )
            .frame(maxWidth: 200)
        }
    }

    private func continueTitle(for step: OnboardingStep) -> String {
        step == .funding ? "Finish" : "Continue"
    }

    private func continueIcon(for step: OnboardingStep) -> String {
        step == .funding ? "checkmark" : "arrow.right"
    }
}

// MARK: - Shared step header

/// Title + subtitle block shown at the top of each onboarding step body.
struct OnboardingStepHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs) {
            Text(step.title)
                .font(Theme.font.title)
                .foregroundStyle(Theme.color.textPrimary)
            Text(step.subtitle)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Model step") {
    OnboardingContainerView()
        .environment(AppState())
        .frame(width: 820, height: 720)
        .preferredColorScheme(.dark)
}

#Preview("Funding step") {
    let state = AppState()
    state.onboarding.step = .funding
    state.onboarding.coinbase = .connected
    return OnboardingContainerView()
        .environment(state)
        .frame(width: 820, height: 720)
        .preferredColorScheme(.dark)
}
