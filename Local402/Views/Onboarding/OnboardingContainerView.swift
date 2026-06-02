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

    private let columnWidth: CGFloat = 580

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
                Local402Flourish(size: 18)
                Text("Local402")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
                    .tracking(0.3)
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

            SkipButton { appState.completeOnboarding() }

            Spacer()

            PrimaryButton(
                title: continueTitle(for: onboarding.step),
                systemImage: continueIcon(for: onboarding.step),
                isEnabled: onboarding.canContinue,
                action: onboarding.advance
            )
            .frame(maxWidth: 200)
        }
        .padding(.top, Theme.spacing.sm)
    }

    private func continueTitle(for step: OnboardingStep) -> String {
        step == .funding ? "Finish" : "Continue"
    }

    private func continueIcon(for step: OnboardingStep) -> String {
        step == .funding ? "checkmark" : "arrow.right"
    }
}

// MARK: - Skip text button

/// A muted, hover-aware "Skip for now" text button used in the bottom nav.
private struct SkipButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button("Skip for now", action: action)
            .buttonStyle(.plain)
            .font(Theme.font.callout)
            .foregroundStyle(hovering ? Theme.color.textSecondary : Theme.color.textTertiary)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
            .help("Skip onboarding and enter Local402")
    }
}

// MARK: - Shared step header

/// Title + subtitle block shown at the top of each onboarding step body, with a
/// leading flourish accent for the Copilot-style brand gesture.
struct OnboardingStepHeader: View {
    let step: OnboardingStep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.md) {
            Local402Flourish(size: 22)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }

            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text(step.title)
                    .font(Theme.font.title)
                    .foregroundStyle(Theme.color.textPrimary)
                Text(step.subtitle)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
