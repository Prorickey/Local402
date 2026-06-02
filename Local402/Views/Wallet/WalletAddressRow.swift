//
//  WalletAddressRow.swift
//  Local402
//
//  Displays the wallet address (truncated) with a copy-to-pasteboard button
//  that copies the full address and shows a transient "Copied!" confirmation.
//  Rendered on a Fluent acrylic surface with desktop hover affordances.
//

import SwiftUI
import AppKit
import os

struct WalletAddressRow: View {
    let address: String
    let shortAddress: String

    @State private var didCopy = false
    @State private var rowHovering = false

    private static let logger = Logger(subsystem: "Local402", category: "WalletAddressRow")
    private static let copiedResetDelay: Duration = .milliseconds(1500)

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            iconBadge
            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text("Wallet address")
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
                    .tracking(0.6)
                    .textCase(.uppercase)
                Text(shortAddress)
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textPrimary)
                    .textSelection(.enabled)
            }
            Spacer()
            copyButton
        }
        .padding(Theme.spacing.lg)
        .local402Acrylic(cornerRadius: Theme.radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                .strokeBorder(Theme.color.accent.opacity(rowHovering ? 0.35 : 0), lineWidth: 1)
        )
        .onHover { rowHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: rowHovering)
    }

    // MARK: - Components

    private var iconBadge: some View {
        Image(systemName: "wallet.bifold")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.color.accent)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
    }

    private var copyButton: some View {
        Button(action: copyAddress) {
            HStack(spacing: Theme.spacing.xs) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                Text(didCopy ? "Copied!" : "Copy")
            }
            .font(Theme.font.callout)
            .foregroundStyle(didCopy ? Theme.color.paymentGreen : Theme.color.textSecondary)
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .fill(Theme.color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.md, style: .continuous)
                    .stroke(didCopy ? Theme.color.paymentGreen.opacity(0.4) : Theme.color.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(Local402PressableStyle())
        .disabled(address.isEmpty)
        .help("Copy address")
        .animation(.easeOut(duration: 0.15), value: didCopy)
    }

    // MARK: - Actions

    private func copyAddress() {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Self.logger.warning("Refused to copy empty wallet address")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)
        Self.logger.info("Copied wallet address to pasteboard")

        didCopy = true
        Task {
            try? await Task.sleep(for: Self.copiedResetDelay)
            didCopy = false
        }
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        WalletAddressRow(
            address: MockWallet.address,
            shortAddress: MockWallet.initialWallet().shortAddress
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560, height: 180)
    .preferredColorScheme(.dark)
}
