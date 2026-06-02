//
//  ModelOptionCard.swift
//  Local402
//
//  A selectable local-model card. Shows model metadata and, once selected,
//  surfaces simulated download progress and a "Ready" confirmation.
//

import SwiftUI

struct ModelOptionCard: View {
    let model: LLMModelOption
    let isSelected: Bool
    let downloadProgress: Double
    let isDownloading: Bool
    let isReady: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.spacing.md) {
                header
                Text(model.description)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                specs
                if isSelected {
                    statusSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacing.lg)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: hovering)
        .animation(.easeInOut(duration: 0.25), value: isReady)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.spacing.sm) {
            Text(model.name)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)

            Text(model.parameters)
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.accentHover)
                .padding(.vertical, 2)
                .padding(.horizontal, Theme.spacing.sm)
                .background(Capsule().fill(Theme.color.accent.opacity(0.15)))

            Spacer(minLength: Theme.spacing.sm)

            if model.isRecommended {
                recommendedPill
            }

            selectionIndicator
        }
    }

    private var recommendedPill: some View {
        Text("Recommended")
            .font(Theme.font.caption)
            .foregroundStyle(Theme.color.paymentGreen)
            .padding(.vertical, 3)
            .padding(.horizontal, Theme.spacing.sm)
            .background(Capsule().fill(Theme.color.paymentGreenSoft))
            .overlay(Capsule().stroke(Theme.color.paymentGreen.opacity(0.35), lineWidth: 1))
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Theme.color.accent : Theme.color.surfaceStroke, lineWidth: 1.5)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(Theme.color.accent)
                    .frame(width: 10, height: 10)
                    .transition(.scale)
            }
        }
    }

    // MARK: - Specs

    private var specs: some View {
        HStack(spacing: Theme.spacing.lg) {
            spec(systemImage: "internaldrive", text: model.sizeLabel)
            spec(systemImage: "memorychip", text: model.ramLabel)
        }
    }

    private func spec(systemImage: String, text: String) -> some View {
        HStack(spacing: Theme.spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
            Text(text)
                .font(Theme.font.callout)
        }
        .foregroundStyle(Theme.color.textTertiary)
    }

    // MARK: - Status (download / ready)

    @ViewBuilder
    private var statusSection: some View {
        if isReady {
            readyRow
        } else if isDownloading {
            downloadingRow
        }
    }

    private var readyRow: some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.color.paymentGreen)
            Text("Ready")
                .font(Theme.font.callout)
                .foregroundStyle(Theme.color.paymentGreen)
            Spacer()
        }
        .padding(.top, Theme.spacing.xs)
    }

    private var downloadingRow: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            HStack {
                Text("Downloading…")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.textSecondary)
                Spacer()
                Text("\(Int((downloadProgress * 100).rounded()))%")
                    .font(Theme.font.callout)
                    .foregroundStyle(Theme.color.accentHover)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            progressBar
        }
        .padding(.top, Theme.spacing.xs)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.color.surfaceStroke)
                Capsule()
                    .fill(Theme.color.accent)
                    .frame(width: max(0, proxy.size.width * downloadProgress))
                    .animation(.easeInOut(duration: 0.2), value: downloadProgress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Background & border

    private var background: some View {
        RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
            .fill(isSelected ? Theme.color.surfaceElevated : Theme.color.surface)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
            .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
    }

    private var borderColor: Color {
        if isSelected { return Theme.color.accent }
        return hovering ? Theme.color.accent.opacity(0.5) : Theme.color.surfaceStroke
    }
}

#Preview("Selected & Ready") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ModelOptionCard(
            model: MockModels.all[0],
            isSelected: true,
            downloadProgress: 1,
            isDownloading: false,
            isReady: true,
            onSelect: {}
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 320)
    .preferredColorScheme(.dark)
}

#Preview("Unselected") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ModelOptionCard(
            model: MockModels.all[0],
            isSelected: false,
            downloadProgress: 0,
            isDownloading: false,
            isReady: false,
            onSelect: {}
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 280)
    .preferredColorScheme(.dark)
}

#Preview("Downloading") {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ModelOptionCard(
            model: MockModels.all[0],
            isSelected: true,
            downloadProgress: 0.45,
            isDownloading: true,
            isReady: false,
            onSelect: {}
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 320)
    .preferredColorScheme(.dark)
}
