//
//  AppTopBar.swift
//  Local402
//
//  The in-app top bar: branding + chat affordance on the left, Wallet and
//  Settings tab buttons on the right.
//

import SwiftUI

struct AppTopBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            brand
            TopBarTabButton(
                tab: .rag,
                isSelected: appState.selectedTab == .rag,
                badge: nil
            ) {
                appState.selectedTab = .rag
            }
            Spacer(minLength: Theme.spacing.lg)
            ForEach(AppTab.secondaryTabs, id: \.self) { tab in
                TopBarTabButton(
                    tab: tab,
                    isSelected: appState.selectedTab == tab,
                    badge: tab == .wallet ? appState.wallet.wallet.balanceLabel : nil
                ) {
                    appState.selectedTab = tab
                }
            }
        }
        .padding(.horizontal, Theme.spacing.xl)
        .padding(.vertical, Theme.spacing.md)
        .background(Theme.color.surface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.color.surfaceStroke)
                .frame(height: 1)
        }
    }

    private var brand: some View {
        Button {
            appState.selectedTab = .chat
        } label: {
            HStack(spacing: Theme.spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                        .fill(Theme.color.accent)
                        .frame(width: 24, height: 24)
                    Text("4")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Local402")
                        .font(Theme.font.headline)
                        .foregroundStyle(Theme.color.textPrimary)
                    Text(appState.selectedModelName)
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TopBarTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    var badge: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(badge ?? tab.title)
                    .font(Theme.font.callout)
            }
            .foregroundStyle(isSelected ? Theme.color.textPrimary : Theme.color.textSecondary)
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .stroke(isSelected ? Theme.color.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tab.title)
    }

    private var background: Color {
        if isSelected { return Theme.color.accent.opacity(0.18) }
        return hovering ? Theme.color.surfaceElevated : Color.clear
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        VStack {
            AppTopBar()
            Spacer()
        }
    }
    .environment(AppState())
    .frame(width: 1000, height: 200)
    .preferredColorScheme(.dark)
}
