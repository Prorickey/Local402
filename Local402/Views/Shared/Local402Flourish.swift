//
//  Local402Flourish.swift
//  Local402
//
//  The brand flourish mark — a blue gradient sparkle used as the assistant's
//  avatar and for brand emphasis. Decorative for accessibility. See DESIGN.md §3.
//

import SwiftUI

struct Local402Flourish: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(LinearGradient.local402Flourish)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
