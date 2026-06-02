//
//  PrimaryButton.swift
//  Local402
//
//  Large accent call-to-action button with an optional leading icon.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(AccentButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        VStack(spacing: Theme.spacing.lg) {
            PrimaryButton(title: "Continue", systemImage: "arrow.right") {}
            PrimaryButton(title: "Continue", systemImage: "arrow.right", isEnabled: false) {}
        }
        .padding(Theme.spacing.xxl)
    }
    .frame(width: 360, height: 220)
    .preferredColorScheme(.dark)
}
