//
//  OnboardingStep.swift
//  Local402
//
//  The ordered steps of the onboarding flow.
//

import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case model
    case data
    case coinbase
    case funding
    case complete

    var id: Int { rawValue }

    /// Steps shown in the progress indicator (excludes the final success splash).
    static var progressSteps: [OnboardingStep] {
        [.model, .data, .coinbase, .funding]
    }

    var title: String {
        switch self {
        case .model: return "Choose a local model"
        case .data: return "Add company context"
        case .coinbase: return "Connect Coinbase"
        case .funding: return "Fund your wallet"
        case .complete: return "You're all set"
        }
    }

    var subtitle: String {
        switch self {
        case .model: return "Pick a model to run privately on your machine."
        case .data: return "Drop in files your agents can reference while they work."
        case .coinbase: return "Link a wallet so your agents can pay for what they use."
        case .funding: return "Add a starting balance the agent will spend against."
        case .complete: return "Local402 is ready to go."
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        guard rawValue > 0 else { return nil }
        return OnboardingStep(rawValue: rawValue - 1)
    }
}
