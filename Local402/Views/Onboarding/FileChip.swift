//
//  FileChip.swift
//  Local402
//
//  A compact chip representing an added company context file, with a remove
//  affordance.
//

import SwiftUI

struct FileChip: View {
    let file: ContextFile
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                    .fill(Theme.color.accent.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: file.systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.accentHover)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.sizeLabel)
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(hovering ? Theme.color.textPrimary : Theme.color.textTertiary)
                    .padding(4)
                    .background(
                        Circle().fill(hovering ? Theme.color.surfaceStroke : .clear)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(Local402PressableStyle())
            .help("Remove \(file.fileName)")
        }
        .padding(.vertical, Theme.spacing.sm)
        .padding(.horizontal, Theme.spacing.md)
        .local402Acrylic(cornerRadius: Theme.radius.md, appears: false)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                .strokeBorder(
                    hovering ? Theme.color.accent.opacity(0.4) : Theme.color.surfaceStroke,
                    lineWidth: 1
                )
        )
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        FileChip(file: MockFiles.seeded[0]) {}
            .padding(Theme.spacing.xl)
    }
    .frame(width: 360, height: 140)
    .preferredColorScheme(.dark)
}
