//
//  MainView.swift
//  Local402
//
//  The main app shell: a collapsible chat-history sidebar beside the top bar
//  and the selected surface (chat is default). See DESIGN.md §5.
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    /// Owns the collapsible history sidebar state for the shell.
    @State private var historyOpen = true

    var body: some View {
        HStack(spacing: 0) {
            if historyOpen {
                Local402HistorySidebar()
                    .frame(width: 280)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                AppTopBar(historyOpen: $historyOpen)

                Divider()
                    .overlay(Theme.color.surfaceStroke)

                Group {
                    switch appState.selectedTab {
                    case .chat:
                        ChatView()
                    case .rag:
                        RAGTerminalView()
                    case .wallet:
                        WalletView()
                    case .settings:
                        SettingsView()
                    }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: appState.selectedTab)
        }
        .background(Theme.color.background)
        .animation(.easeOut(duration: 0.25), value: historyOpen)
    }
}

#Preview {
    MainView()
        .environment(AppState())
        .frame(width: 1100, height: 760)
        .preferredColorScheme(.dark)
}
