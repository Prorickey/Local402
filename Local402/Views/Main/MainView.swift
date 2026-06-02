//
//  MainView.swift
//  Local402
//
//  The main app shell: top bar plus the selected surface (chat is default).
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar()

            Group {
                switch appState.selectedTab {
                case .chat:
                    ChatView()
                case .wallet:
                    WalletView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.selectedTab)
        .background(Theme.color.background)
    }
}

#Preview {
    MainView()
        .environment(AppState())
        .frame(width: 1000, height: 720)
        .preferredColorScheme(.dark)
}
