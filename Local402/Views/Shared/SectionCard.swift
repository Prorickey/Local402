//
//  SectionCard.swift
//  Local402
//
//  A titled rounded surface container for grouping content.
//

import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                    .tracking(0.6)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        SectionCard("Example") {
            Text("Body")
                .foregroundStyle(Theme.color.textPrimary)
        }
        .padding(Theme.spacing.xl)
    }
    .frame(width: 480, height: 220)
    .preferredColorScheme(.dark)
}
