//
//  DataDropStepView.swift
//  Local402
//
//  Step B: add company context PDFs. Documents are ingested into the on-device
//  vector store for real — parsed, chunked, and embedded — and shown as
//  removable chips. The list mirrors what's actually stored.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataDropStepView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: Theme.spacing.sm)
    ]

    private var rag: RAGStore { appState.rag }
    private var onboarding: OnboardingState { appState.onboarding }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xl) {
            OnboardingStepHeader(step: .data)

            DropZoneView(
                onBrowse: { showImporter = true },
                onDropURLs: { rag.addPDFs($0) }
            )
            .disabled(!rag.isReady)
            .opacity(rag.isReady ? 1 : 0.6)

            if !rag.isReady || rag.isIngesting {
                statusRow
            }

            if !onboarding.files.isEmpty {
                fileSection(files: onboarding.files)
            }
        }
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
        .task {
            await rag.bootstrap()
            onboarding.syncDocuments(rag.documents)
        }
        .onChange(of: rag.documents) { _, docs in
            onboarding.syncDocuments(docs)
        }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: Theme.spacing.sm) {
            if rag.isIngesting {
                ProgressView(value: rag.ingestProgress)
                    .frame(width: 160)
                    .controlSize(.small)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(rag.isReady ? rag.statusMessage : "Preparing on-device embedding engine…")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    // MARK: - Files

    private func fileSection(files: [ContextFile]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            HStack {
                Text("Added files")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                    .tracking(0.6)
                    .textCase(.uppercase)
                Spacer()
                Text(summary(for: files))
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.spacing.sm) {
                ForEach(files) { file in
                    FileChip(file: file) { remove(file) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: files)
    }

    /// A chip's id is the document id, so removal maps straight back to the store.
    private func remove(_ file: ContextFile) {
        if let doc = rag.documents.first(where: { $0.id == file.id.uuidString }) {
            rag.delete(doc)
        }
    }

    private func summary(for files: [ContextFile]) -> String {
        let totalBytes = files.reduce(0) { $0 + $1.sizeBytes }
        let sizeLabel = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
        let fileWord = files.count == 1 ? "file" : "files"
        return "\(files.count) \(fileWord) · \(sizeLabel)"
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            DataDropStepView()
                .frame(maxWidth: 560)
                .padding(Theme.spacing.xl)
        }
    }
    .environment(AppState())
    .frame(width: 640, height: 720)
    .preferredColorScheme(.dark)
}
