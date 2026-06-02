//
//  ChatInputBar.swift
//  Local402
//
//  Bottom composer: a growing text field plus a circular send/stop button.
//  Sends the draft on Enter or tap; shows a stop control while streaming.
//

import SwiftUI

struct ChatInputBar: View {
    @Environment(AppState.self) private var appState

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var chat = appState.chat

        VStack(spacing: Theme.spacing.sm) {
            Divider()
                .overlay(Theme.color.surfaceStroke)

            HStack(alignment: .bottom, spacing: Theme.spacing.md) {
                field(draft: $chat.draft)
                actionButton
            }

            Text("Agents weigh cost before every paid call.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Theme.spacing.lg)
        .background(Theme.color.background)
    }

    // MARK: - Text field

    private func field(draft: Binding<String>) -> some View {
        TextField("Message Local402…", text: draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(Theme.font.body)
            .foregroundStyle(Theme.color.textPrimary)
            .tint(Theme.color.accent)
            .lineLimit(1...6)
            .focused($isFocused)
            .onSubmit(submit)
            .padding(.vertical, Theme.spacing.md)
            .padding(.horizontal, Theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                    .stroke(Theme.color.surfaceStroke, lineWidth: 1)
            )
    }

    // MARK: - Send / Stop button

    @ViewBuilder
    private var actionButton: some View {
        if appState.chat.isStreaming {
            circularButton(systemImage: "stop.fill", fill: Theme.color.surfaceElevated) {
                appState.chat.cancelStreaming()
            }
            .accessibilityLabel("Stop generating")
        } else {
            circularButton(
                systemImage: "arrow.up",
                fill: canSend ? Theme.color.accent : Theme.color.surfaceElevated,
                action: submit
            )
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
    }

    private func circularButton(
        systemImage: String,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var canSend: Bool {
        !appState.chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !appState.chat.isStreaming
    }

    private func submit() {
        guard canSend else { return }
        appState.chat.send()
        isFocused = true
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        VStack {
            Spacer()
            ChatInputBar()
        }
    }
    .environment(AppState())
    .frame(width: 640, height: 220)
    .preferredColorScheme(.dark)
}
