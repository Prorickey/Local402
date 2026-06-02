//
//  RAGStatsView.swift
//  Local402
//
//  The vector-store stats card: a at-a-glance view of what's on device — how
//  many documents and chunks, embedding dimensionality, and on-disk size.
//

import SwiftUI

struct RAGStatsView: View {
    let rag: RAGStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            HStack(spacing: Theme.spacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.paymentGreen)
                Text("VECTOR STORE · ON-DEVICE")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                    .tracking(0.6)
                Spacer()
            }

            HStack(spacing: 0) {
                StatTile(value: "\(rag.documents.count)", label: "Documents", systemImage: "doc.on.doc")
                tileDivider
                StatTile(value: "\(rag.totalChunks)", label: "Chunks", systemImage: "square.stack.3d.up")
                tileDivider
                StatTile(value: rag.embeddingDimension > 0 ? "\(rag.embeddingDimension)" : "—",
                         label: "Dimensions", systemImage: "ruler")
                tileDivider
                StatTile(value: rag.databaseSizeLabel, label: "On disk", systemImage: "internaldrive")
            }

            if !rag.databasePath.isEmpty {
                Text(rag.databasePath)
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var tileDivider: some View {
        Rectangle()
            .fill(Theme.color.surfaceStroke)
            .frame(width: 1, height: 34)
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Theme.spacing.xs) {
            Text(value)
                .font(Theme.font.title)
                .foregroundStyle(Theme.color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Label(label, systemImage: systemImage)
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
