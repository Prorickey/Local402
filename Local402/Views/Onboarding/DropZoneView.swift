//
//  DropZoneView.swift
//  Local402
//
//  A dashed drop target for company documents. Tapping opens a file browser;
//  dropping real PDF file URLs hands them to `onDropURLs` for on-device
//  ingestion into the vector store.
//

import SwiftUI

struct DropZoneView: View {
    var onBrowse: () -> Void
    var onDropURLs: ([URL]) -> Void

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
                Text("Drag PDFs here or click to browse")
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.textPrimary)
                Text("Each PDF is parsed, chunked, and embedded on-device — nothing leaves your machine.")
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
        .onTapGesture(perform: onBrowse)
        .onHover { hovering = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            guard !pdfs.isEmpty else { return false }
            onDropURLs(pdfs)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .help("Add a PDF to your agent's context")
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
        DropZoneView(onBrowse: {}, onDropURLs: { _ in })
            .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 260)
    .preferredColorScheme(.dark)
}
