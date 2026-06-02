//
//  Local402App.swift
//  Local402
//
//  Created by Trevor Bedson & Joshua Chilukuri on 6/2/26.
//

import SwiftUI

@main
struct Local402App: App {
    @State private var appState: AppState

    init() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        _appState = State(initialValue: AppState(hasCompletedOnboarding: completed))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1000, height: 720)
    }
}
