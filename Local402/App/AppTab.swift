//
//  AppTab.swift
//  Local402
//
//  The selectable surfaces in the main app's top bar.
//

import Foundation

enum AppTab: Hashable, CaseIterable {
    case chat
    case wallet
    case settings

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .wallet: return "Wallet"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: return "bubble.left.and.text.bubble.right"
        case .wallet: return "dollarsign.circle"
        case .settings: return "gearshape"
        }
    }

    /// Tabs surfaced as buttons on the right of the top bar.
    static let secondaryTabs: [AppTab] = [.wallet, .settings]
}
