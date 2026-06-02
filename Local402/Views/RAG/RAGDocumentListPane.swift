//
//  RAGDocumentListPane.swift
//  Local402
//
//  Left pane of the RAG terminal: the on-device document store. Lists ingested
//  PDFs, lets you select one to inspect, add new ones, or clear the store.
//

import SwiftUI

struct RAGDocumentListPane: View {
    let rag: RAGStore
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            if rag.documents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.spacing.xs) {
                        ForEach(rag.documents) { doc in
                            RAGDocRow(
                                doc: doc,
                                isSelected: rag.selectedDocumentID == doc.id,
                                onSelect: { rag.select(doc) },
                                onDelete: { rag.delete(doc) }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.spacing.md)
                    .padding(.vertical, Theme.spacing.sm)
                }
            }

            Divider().overlay(Theme.color.surfaceStroke)
            footer
        }
        .background(Theme.color.surface.opacity(0.35))
    }

    private var header: some View {
        HStack {
            Text("Document Store")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .tracking(0.6)
            Spacer()
            if !rag.documents.isEmpty {
                Text("\(rag.documents.count)")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.top, Theme.spacing.lg)
        .padding(.bottom, Theme.spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Theme.color.textTertiary)
            Text("No documents yet")
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.textSecondary)
            Text("Add a PDF to embed it locally and build the vector store.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.spacing.lg)
    }

    private var footer: some View {
        VStack(spacing: Theme.spacing.sm) {
            PrimaryButton(title: "Add PDF", systemImage: "plus", isEnabled: !rag.isIngesting, action: onAdd)

            if !rag.documents.isEmpty {
                Button(role: .destructive) {
                    rag.clearAll()
                } label: {
                    Text("Clear all")
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(rag.isIngesting)
            }
        }
        .padding(Theme.spacing.md)
    }
}

private struct RAGDocRow: View {
    let doc: DocumentMeta
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.color.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(doc.filename)
                        .font(Theme.font.callout)
                        .foregroundStyle(Theme.color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(doc.pageCount) pages · \(doc.chunkCount) chunks")
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textTertiary)
                }
                Spacer(minLength: 0)
                if hovering || isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from store")
                }
            }
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .stroke(isSelected ? Theme.color.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button { onSelect() } label: { Label("Inspect Chunks & Embeddings", systemImage: "eye") }
            Button(role: .destructive) { onDelete() } label: { Label("Remove", systemImage: "trash") }
        }
    }

    private var rowFill: Color {
        if isSelected { return Theme.color.accent.opacity(0.18) }
        return hovering ? Theme.color.surfaceElevated : Color.clear
    }
}
