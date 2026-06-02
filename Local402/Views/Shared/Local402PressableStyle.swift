//
//  Local402PressableStyle.swift
//  Local402
//
//  Subtle spring press-scale for chips and pill buttons (Copilot feel).
//  See DESIGN.md §3.
//

import SwiftUI

struct Local402PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
