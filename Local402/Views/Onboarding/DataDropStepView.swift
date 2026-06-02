//
//  DataDropStepView.swift
//  Local402
//
//  Step B: add company context files via the drop zone, shown as removable
//  chips with a running count + total size summary.
//

import SwiftUI

struct DataDropStepView: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: Theme.spacing.sm)
    ]

    var body: some View {
        let onboarding = appState.onboarding

        VStack(alignment: .leading, spacing: Theme.spacing.xl) {
            OnboardingStepHeader(step: .data)

            DropZoneView { onboarding.addFile() }

            if !onboarding.files.isEmpty {
                fileSection(files: onboarding.files, onRemove: onboarding.removeFile)
            }
        }
    }

    // MARK: - Files

    private func fileSection(
        files: [ContextFile],
        onRemove: @escaping (ContextFile) -> Void
    ) -> some View {
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
                    FileChip(file: file) { onRemove(file) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: files)
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
