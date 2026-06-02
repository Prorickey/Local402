//
//  RAGRetrieveInspect.swift
//  Local402
//
//  Right-pane content for the RAG terminal:
//   • RAGRetrieveView   — embed a query on-device, show nearest chunks.
//   • RAGInspectorView  — the selected document's stored chunks + embeddings.
//

import SwiftUI
import AppKit

// MARK: - Retrieve

struct RAGRetrieveView: View {
    @Bindable var rag: RAGStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            searchField

            if rag.results.isEmpty {
                placeholder
            } else {
                LazyVStack(spacing: Theme.spacing.md) {
                    ForEach(Array(rag.results.enumerated()), id: \.element.id) { idx, result in
                        ResultCard(rank: idx + 1, result: result)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.color.textTertiary)
            TextField("Ask your documents…", text: $rag.query)
                .textFieldStyle(.plain)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textPrimary)
                .onSubmit { rag.runSearch() }
            if rag.isSearching {
                ProgressView().controlSize(.small)
            }
            Button { rag.runSearch() } label: {
                Text("Search")
                    .font(Theme.font.callout)
                    .foregroundStyle(.white)
                    .padding(.vertical, Theme.spacing.xs)
                    .padding(.horizontal, Theme.spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                            .fill(canSearch ? Theme.color.accent : Theme.color.surfaceElevated)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSearch)
        }
        .padding(Theme.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                .fill(Theme.color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                .stroke(Theme.color.surfaceStroke, lineWidth: 1)
        )
    }

    private var canSearch: Bool {
        !rag.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var placeholder: some View {
        VStack(spacing: Theme.spacing.sm) {
            Image(systemName: rag.hasSearched ? "tray" : "text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(Theme.color.textTertiary)
            Text(rag.hasSearched ? "No matching passages" : "Search your local documents")
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textSecondary)
            Text(rag.hasSearched
                 ? "Try rephrasing, or add more documents to the store."
                 : "Queries are embedded on-device and matched against your stored chunks — nothing leaves your machine.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.xxl)
    }
}

private struct ResultCard: View {
    let rank: Int
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            HStack(spacing: Theme.spacing.sm) {
                Text("#\(rank)")
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textTertiary)
                Label("\(result.documentName) · p.\(result.page)", systemImage: "doc.richtext")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                ScoreBadge(score: result.score)
            }
            Text(result.text)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct ScoreBadge: View {
    let score: Double

    var body: some View {
        Text(String(format: "%.0f%%", max(0, score) * 100))
            .font(Theme.font.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.spacing.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.18)))
    }

    private var tint: Color {
        switch score {
        case 0.5...: return Theme.color.paymentGreen
        case 0.3..<0.5: return Theme.color.accent
        default: return Theme.color.textTertiary
        }
    }
}

// MARK: - Inspect

struct RAGInspectorView: View {
    let rag: RAGStore

    var body: some View {
        if let doc = rag.selectedDocument {
            VStack(alignment: .leading, spacing: Theme.spacing.md) {
                header(for: doc)
                if rag.isInspecting {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: Theme.spacing.md) {
                        ForEach(rag.inspectedChunks) { chunk in
                            ChunkCard(chunk: chunk)
                        }
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private func header(for doc: DocumentMeta) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(doc.filename)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(doc.pageCount) pages · \(rag.inspectedChunks.count) chunks · \(rag.embeddingDimension)-d embeddings")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
        }
    }

    private var placeholder: some View {
        VStack(spacing: Theme.spacing.sm) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 34))
                .foregroundStyle(Theme.color.textTertiary)
            Text("Select a document to inspect")
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textSecondary)
            Text("See its parsed chunks and the on-device embedding vectors that power retrieval.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.xxl)
    }
}

private struct ChunkCard: View {
    let chunk: StoredChunk
    @State private var showVector = false

    private var stats: (norm: Double, minV: Float, maxV: Float) {
        guard !chunk.embedding.isEmpty else { return (0, 0, 0) }
        let norm = chunk.embedding.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
        return (norm, chunk.embedding.min() ?? 0, chunk.embedding.max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            HStack(spacing: Theme.spacing.sm) {
                Text("#\(chunk.chunkIndex)")
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textTertiary)
                Text("p.\(chunk.page)")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                Spacer()
                Text("\(chunk.text.split(separator: " ").count) words")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }

            Text(chunk.text)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Theme.color.surfaceStroke).frame(height: 1)

            if chunk.embedding.isEmpty {
                Label("Not embedded", systemImage: "exclamationmark.triangle")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.accentHover)
            } else {
                embeddingSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.color.surfaceElevated)
    }

    private var embeddingSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            HStack(spacing: Theme.spacing.lg) {
                statChip("dim", "\(chunk.embedding.count)")
                statChip("‖v‖", String(format: "%.2f", stats.norm))
                statChip("min", String(format: "%.2f", stats.minV))
                statChip("max", String(format: "%.2f", stats.maxV))
                Spacer()
                Button { copyVector() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Copy the full vector as CSV")
            }

            VectorBarStrip(values: chunk.embedding)

            DisclosureGroup(isExpanded: $showVector) {
                Text(formattedVector)
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textTertiary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.spacing.xs)
            } label: {
                Text("Full \(chunk.embedding.count)-d vector")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textSecondary)
            }
            .tint(Theme.color.accent)
        }
    }

    private func statChip(_ key: String, _ value: String) -> some View {
        HStack(spacing: Theme.spacing.xs) {
            Text(key).font(Theme.font.caption).foregroundStyle(Theme.color.textTertiary)
            Text(value).font(Theme.font.mono).foregroundStyle(Theme.color.textSecondary)
        }
    }

    private var formattedVector: String {
        chunk.embedding.map { String(format: "% .4f", $0) }.joined(separator: ", ")
    }

    private func copyVector() {
        let csv = chunk.embedding.map { String(format: "%.6f", $0) }.joined(separator: ",")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csv, forType: .string)
    }
}

/// A compact visual "fingerprint" of the first slice of a vector: one bar per
/// dimension, height ∝ |value|, accent for positive / red for negative.
private struct VectorBarStrip: View {
    let values: [Float]
    var maxBars = 96

    var body: some View {
        let slice = Array(values.prefix(maxBars))
        let maxAbs = max(slice.map { abs($0) }.max() ?? 1, 0.0001)
        VStack(alignment: .leading, spacing: Theme.spacing.xs) {
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(slice.enumerated()), id: \.offset) { _, v in
                    Rectangle()
                        .fill(v >= 0 ? Theme.color.accent : Color(hex: "#F87171"))
                        .frame(width: 3, height: max(1, CGFloat(abs(v) / maxAbs) * 28))
                }
            }
            .frame(height: 28, alignment: .bottom)
            Text("first \(slice.count) of \(values.count) dims")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
        }
    }
}
