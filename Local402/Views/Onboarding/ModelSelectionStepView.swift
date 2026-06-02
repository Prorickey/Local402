//
//  ModelSelectionStepView.swift
//  Local402
//
//  Step A: pick a local model. Selecting a card kicks off the simulated
//  download in OnboardingState.
//

import SwiftUI

struct ModelSelectionStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let onboarding = appState.onboarding

        VStack(alignment: .leading, spacing: Theme.spacing.xl) {
            OnboardingStepHeader(step: .model)

            VStack(spacing: Theme.spacing.md) {
                ForEach(MockModels.all) { model in
                    ModelOptionCard(
                        model: model,
                        isSelected: onboarding.selectedModel?.id == model.id,
                        downloadProgress: onboarding.downloadProgress,
                        isDownloading: onboarding.isDownloading,
                        isReady: onboarding.isModelReady,
                        onSelect: { onboarding.selectModel(model) }
                    )
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            ModelSelectionStepView()
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(AppState())
    .frame(width: 640, height: 720)
    .preferredColorScheme(.dark)
}
