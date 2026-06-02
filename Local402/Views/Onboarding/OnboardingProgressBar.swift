//
//  OnboardingProgressBar.swift
//  Local402
//
//  Horizontal stepper indicator for the visible onboarding steps. Completed
//  steps fill accent with a checkmark, the current step shows an accent ring,
//  and upcoming steps stay muted. Connectors fill as progress advances.
//

import SwiftUI

struct OnboardingProgressBar: View {
    let current: OnboardingStep

    private let steps = OnboardingStep.progressSteps

    var body: some View {
        HStack(spacing: Theme.spacing.xs) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                node(for: step)

                if index < steps.count - 1 {
                    connector(after: step)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: current)
    }

    // MARK: - Node

    private func node(for step: OnboardingStep) -> some View {
        let state = state(for: step)
        return ZStack {
            Circle()
                .fill(fill(for: state))
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(ring(for: state), lineWidth: state == .current ? 2 : 1)
                )

            switch state {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            case .current, .upcoming:
                Text("\(step.rawValue + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(numberColor(for: state))
            }
        }
        .accessibilityLabel(Text(step.title))
    }

    private func connector(after step: OnboardingStep) -> some View {
        let filled = step.rawValue < current.rawValue
        return Capsule()
            .fill(filled ? Theme.color.accent : Theme.color.surfaceStroke)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    // MARK: - State

    private enum NodeState {
        case completed
        case current
        case upcoming
    }

    private func state(for step: OnboardingStep) -> NodeState {
        if step.rawValue < current.rawValue { return .completed }
        if step.rawValue == current.rawValue { return .current }
        return .upcoming
    }

    private func fill(for state: NodeState) -> Color {
        switch state {
        case .completed: return Theme.color.accent
        case .current: return Theme.color.accent.opacity(0.15)
        case .upcoming: return Theme.color.surface
        }
    }

    private func ring(for state: NodeState) -> Color {
        switch state {
        case .completed: return Theme.color.accent
        case .current: return Theme.color.accent
        case .upcoming: return Theme.color.surfaceStroke
        }
    }

    private func numberColor(for state: NodeState) -> Color {
        switch state {
        case .current: return Theme.color.accentHover
        case .upcoming: return Theme.color.textTertiary
        case .completed: return .white
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        OnboardingProgressBar(current: .coinbase)
            .padding(Theme.spacing.xxl)
    }
    .frame(width: 520, height: 160)
    .preferredColorScheme(.dark)
}
