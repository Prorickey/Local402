//
//  ChatInputBar.swift
//  Local402
//
//  Bottom composer: a Copilot-style acrylic prompt bar with an animated accent
//  focus ring, a leading "add context" button, a growing text field, and a
//  circular send/stop button. Sends on Enter or ⌘↵; shows a stop control while
//  streaming. See DESIGN.md §3.
//

import SwiftUI

struct ChatInputBar: View {
    @Environment(AppState.self) private var appState

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        @Bindable var chat = appState.chat

        VStack(spacing: Theme.spacing.sm) {
            promptBar(draft: $chat.draft)

            Text("Agents weigh cost before every paid call.")
                .font(Theme.font.caption)
                .foregroundStyle(Theme.color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Theme.spacing.lg)
        .frame(maxWidth: Self.maxWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.color.background)
    }

    private static let maxWidth: CGFloat = 760

    // MARK: - Prompt bar

    private func promptBar(draft: Binding<String>) -> some View {
        HStack(spacing: Theme.spacing.md) {
            iconButton("plus", help: "Add context") { }

            TextField("Message Local402", text: draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.font.body)
                .foregroundStyle(Theme.color.textPrimary)
                .tint(Theme.color.accent)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit(submit)

            actionButton
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.sm)
        .frame(minHeight: 52)
        .background(promptSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.xl, style: .continuous)
                .strokeBorder(
                    isFocused ? Theme.color.accent : Theme.color.surfaceStroke,
                    lineWidth: isFocused ? 1.5 : 1
                )
                .animation(.easeOut(duration: 0.18), value: isFocused)
        )
        // ⌘↵ always sends, even mid-edit.
        .background(
            Button("", action: submit)
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
        )
    }

    @ViewBuilder private var promptSurface: some View {
        if reduceTransparency {
            Theme.color.surfaceElevated
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Theme.color.surfaceElevated.opacity(0.6)
            }
        }
    }

    // MARK: - Leading icon button

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundStyle(Theme.color.textSecondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Send / Stop button

    @ViewBuilder
    private var actionButton: some View {
        if appState.chat.isStreaming {
            Button(action: appState.chat.cancelStreaming) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.color.accent))
            }
            .buttonStyle(.plain)
            .help("Stop generating")
            .accessibilityLabel("Stop generating")
        } else {
            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSend ? .white : Theme.color.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(canSend ? Theme.color.accent : Color.clear))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("Send")
            .accessibilityLabel("Send message")
        }
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
    .frame(width: 720, height: 220)
    .preferredColorScheme(.dark)
}
