//
//  Local402SpendMode.swift
//  Local402
//
//  Copilot's tone selector, re-themed to Local402's spend posture — how
//  aggressively the agent reaches for paid tools. A segmented capsule with a
//  spring-sliding selected fill. See DESIGN.md §3.
//

import SwiftUI

struct Local402SpendMode: View {
    @Binding var selection: Int      // 0 Frugal, 1 Balanced, 2 Thorough

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let modes = ["Frugal", "Balanced", "Thorough"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.modes.indices, id: \.self) { index in
                segment(at: index)
            }
        }
        .padding(3)
        .background(track)
        .overlay(
            Capsule().strokeBorder(Theme.color.surfaceStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spend mode, \(Self.modes[selection])")
    }

    private func segment(at index: Int) -> some View {
        Text(Self.modes[index])
            .font(Theme.font.callout)
            .foregroundStyle(selection == index ? .white : Theme.color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selection == index ? Theme.color.accent : .clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    selection = index
                }
            }
            .help(Self.modeHelp(index))
    }

    @ViewBuilder private var track: some View {
        if reduceTransparency {
            Capsule().fill(Theme.color.surface)
        } else {
            Capsule().fill(.regularMaterial)
        }
    }

    private static func modeHelp(_ index: Int) -> String {
        ["Avoid paid tools unless essential",
         "Pay when the value clearly beats the cost",
         "Use whatever paid tools improve the answer"][index]
    }
}

private struct SpendModePreview: View {
    @State private var selection = 1

    var body: some View {
        ZStack {
            Theme.color.background.ignoresSafeArea()
            Local402SpendMode(selection: $selection)
                .frame(width: 320)
                .padding(Theme.spacing.xl)
        }
        .frame(width: 480, height: 160)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SpendModePreview()
}
