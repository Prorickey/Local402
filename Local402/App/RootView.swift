//
//  RootView.swift
//  Local402
//
//  Branches between the onboarding flow and the main app, and keeps the
//  persisted onboarding flag in sync with AppState.
//

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Theme.color.backgroundGradient
                .ignoresSafeArea()

            Group {
                if appState.hasCompletedOnboarding {
                    MainView()
                        .transition(.opacity)
                } else {
                    OnboardingContainerView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            // Adopt the persisted value on launch.
            appState.hasCompletedOnboarding = hasCompletedOnboarding
        }
        .onChange(of: appState.hasCompletedOnboarding) { _, newValue in
            // Persist whenever the in-memory flag changes.
            hasCompletedOnboarding = newValue
        }
    }
}
