//
//  RAGTerminalView.swift
//  Local402
//
//  The RAG terminal surface: a local_rag-style two-pane workspace (document
//  store on the left; vector-store stats + retrieve/inspect on the right),
//  styled with the Local402 theme.
//

import SwiftUI
import UniformTypeIdentifiers

struct RAGTerminalView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false

    private var rag: RAGStore { appState.rag }

    var body: some View {
        HStack(spacing: 0) {
            RAGDocumentListPane(rag: rag, onAdd: { showImporter = true })
                .frame(width: 300)

            Rectangle()
                .fill(Theme.color.surfaceStroke)
                .frame(width: 1)

            RAGRightPane(rag: rag)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.color.background)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): rag.addPDFs(urls)
            case .failure(let error): rag.errorMessage = error.localizedDescription
            }
        }
        .task { await rag.bootstrap() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { rag.errorMessage != nil },
                set: { if !$0 { rag.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rag.errorMessage ?? "")
        }
    }
}

// MARK: - Right pane

private struct RAGRightPane: View {
    @Bindable var rag: RAGStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                    RAGStatsView(rag: rag)

                    Picker("View", selection: $rag.mode) {
                        ForEach(RAGPaneMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch rag.mode {
                    case .retrieve: RAGRetrieveView(rag: rag)
                    case .inspect:  RAGInspectorView(rag: rag)
                    }
                }
                .padding(Theme.spacing.xl)
            }

            RAGStatusBar(rag: rag)
        }
    }
}

// MARK: - Status bar

private struct RAGStatusBar: View {
    let rag: RAGStore

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            if rag.isIngesting {
                ProgressView(value: rag.ingestProgress)
                    .frame(width: 150)
                    .controlSize(.small)
            } else if rag.isReady {
                Circle().fill(Theme.color.paymentGreen).frame(width: 7, height: 7)
            }

            Text(rag.statusMessage)
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if rag.embeddingDimension > 0 {
                Label("On-device · \(rag.embeddingDimension)-d", systemImage: "cpu")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.sm)
        .background(Theme.color.surface.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.color.surfaceStroke).frame(height: 1)
        }
    }
}
