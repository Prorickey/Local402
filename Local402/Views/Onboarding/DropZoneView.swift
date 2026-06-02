//
//  DropZoneView.swift
//  Local402
//
//  A dashed drop target for company files. Both tapping and dropping invoke
//  `onDropFile`, which fabricates a mock file — the dropped item's contents
//  are never read (the app is fully simulated and sandbox-safe).
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onDropFile: () -> Void

    @State private var isTargeted = false
    @State private var hovering = false

    var body: some View {
        VStack(spacing: Theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.color.accent.opacity(isTargeted ? 0.22 : 0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(LinearGradient.local402Flourish)
            }
            .scaleEffect(isTargeted ? 1.12 : 1)

            VStack(spacing: Theme.spacing.xs) {
                Text("Drag files here or click to browse")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
                Text("PDFs, spreadsheets, docs — anything your agents should know about.")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.xxl)
        .padding(.horizontal, Theme.spacing.lg)
        .local402Acrylic(cornerRadius: Theme.radius.lg, appears: false)
        .overlay(highlightWash)
        .overlay(border)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDropFile)
        .onHover { hovering = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted.animation(.easeInOut(duration: 0.15))) { _ in
            // Intentionally ignore the dropped providers: this flow is simulated
            // and must never read disk. Fabricate a mock file instead.
            onDropFile()
            return true
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .help("Add a file to your agent's context")
    }

    /// A faint accent wash that brightens when a drag is over the zone.
    private var highlightWash: some View {
        RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
            .fill(Theme.color.accent.opacity(isTargeted ? 0.1 : 0))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
            .strokeBorder(
                borderColor,
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
            )
    }

    private var borderColor: Color {
        if isTargeted { return Theme.color.accent }
        return hovering ? Theme.color.accent.opacity(0.6) : Theme.color.surfaceStroke
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        DropZoneView {}
            .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 260)
    .preferredColorScheme(.dark)
}
