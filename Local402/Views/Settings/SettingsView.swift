//
//  SettingsView.swift
//  Local402
//
//  Full-surface settings page: model, company data, wallet, and app
//  preferences, including a re-run onboarding action.
//

import SwiftUI
import os

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("settings.showCostPills") private var showCostPills = true
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = false

    private static let appVersionLabel = "0.1.0 (demo)"
    private static let filePreviewLimit = 3
    private static let logger = Logger(subsystem: "Local402", category: "SettingsView")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing.xl) {
                title

                modelSection
                companyDataSection
                walletSection
                appSection
            }
            .padding(Theme.spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.color.background)
    }

    // MARK: - Title

    private var title: some View {
        HStack(spacing: Theme.spacing.sm) {
            Local402Flourish(size: 20)
            Text("Settings")
                .font(Theme.font.title)
                .foregroundStyle(Theme.color.textPrimary)
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        SectionCard("Model") {
            VStack(spacing: 0) {
                SettingsRow(
                    title: appState.selectedModelName,
                    subtitle: modelSubtitle,
                    systemImage: "cpu",
                    help: "Active on-device model"
                ) {
                    if let model = appState.onboarding.selectedModel {
                        Text(model.sizeLabel)
                            .font(Theme.font.callout)
                            .foregroundStyle(Theme.color.textSecondary)
                            .monospacedDigit()
                    }
                }

                if let model = appState.onboarding.selectedModel {
                    divider
                    SettingsRow(
                        title: "Parameters",
                        systemImage: "number.square",
                        value: model.parameters
                    )
                    divider
                    SettingsRow(
                        title: "On-disk size",
                        systemImage: "internaldrive",
                        value: model.sizeLabel
                    )
                    divider
                    SettingsRow(
                        title: "Recommended RAM",
                        systemImage: "memorychip",
                        value: model.ramLabel
                    )
                }
            }
        }
    }

    private var modelSubtitle: String? {
        guard let model = appState.onboarding.selectedModel else {
            return "On-device local model"
        }
        return "\(model.parameters) parameters · \(model.ramLabel)"
    }

    // MARK: - Company data

    private var companyDataSection: some View {
        SectionCard("Company data") {
            let files = appState.onboarding.files
            VStack(spacing: 0) {
                SettingsRow(
                    title: filesCountLabel(files.count),
                    subtitle: "Total \(totalSizeLabel(for: files))",
                    systemImage: "folder",
                    value: ""
                )

                ForEach(files.prefix(Self.filePreviewLimit)) { file in
                    divider
                    SettingsRow(
                        title: file.fileName,
                        subtitle: file.typeLabel,
                        systemImage: file.systemImage,
                        value: file.sizeLabel
                    )
                }

                if files.count > Self.filePreviewLimit {
                    divider
                    Text("+ \(files.count - Self.filePreviewLimit) more")
                        .font(Theme.font.caption)
                        .foregroundStyle(Theme.color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Theme.spacing.xs)
                }
            }
        }
    }

    private func filesCountLabel(_ count: Int) -> String {
        count == 1 ? "1 file" : "\(count) files"
    }

    private func totalSizeLabel(for files: [ContextFile]) -> String {
        let totalBytes = files.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    // MARK: - Wallet

    private var walletSection: some View {
        SectionCard("Wallet") {
            VStack(spacing: 0) {
                SettingsRow(
                    title: "Balance",
                    systemImage: "dollarsign.circle",
                    value: appState.wallet.wallet.balanceLabel
                )
                divider
                SettingsRow(
                    title: "Address",
                    systemImage: "number",
                    help: appState.wallet.wallet.address,
                    value: appState.wallet.wallet.shortAddress
                )
                divider
                SettingsRow(
                    title: "Coinbase",
                    systemImage: "link",
                    help: coinbaseStatusText
                ) {
                    coinbaseStatus
                }
            }
        }
    }

    private var coinbaseStatus: some View {
        let connected: Bool = {
            if case .connected = appState.onboarding.coinbase { return true }
            return false
        }()
        let tint = connected ? Theme.color.paymentGreen : Theme.color.textSecondary
        let soft = connected ? Theme.color.paymentGreenSoft : Theme.color.surfaceElevated
        return HStack(spacing: Theme.spacing.xs) {
            Circle()
                .fill(connected ? Theme.color.paymentGreen : Theme.color.textTertiary)
                .frame(width: 6, height: 6)
            Text(coinbaseStatusText)
                .font(Theme.font.callout)
        }
        .foregroundStyle(tint)
        .padding(.vertical, Theme.spacing.xs)
        .padding(.horizontal, Theme.spacing.sm)
        .background(Capsule().fill(soft))
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
    }

    private var coinbaseStatusText: String {
        switch appState.onboarding.coinbase {
        case .connected: return "Connected"
        case .creating: return "Setting up…"
        case .disconnected: return "Not connected"
        case .failed: return "Setup failed"
        }
    }

    // MARK: - App

    private var appSection: some View {
        SectionCard("App") {
            VStack(spacing: 0) {
                SettingsRow(
                    title: "Show cost pills",
                    subtitle: "Display inline x402 payment badges in chat",
                    systemImage: "creditcard",
                    help: "Toggle inline x402 payment badges"
                ) {
                    Toggle("", isOn: $showCostPills)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Theme.color.accent)
                }
                divider
                SettingsRow(
                    title: "Notifications",
                    subtitle: "Notify on completed agent runs",
                    systemImage: "bell",
                    help: "Toggle run-completion notifications"
                ) {
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Theme.color.accent)
                }
                divider
                SettingsRow(
                    title: "Version",
                    systemImage: "info.circle",
                    value: Self.appVersionLabel
                )
                divider
                rerunOnboardingButton
            }
        }
    }

    private var rerunOnboardingButton: some View {
        PrimaryButton(title: "Re-run Onboarding", systemImage: "arrow.counterclockwise") {
            Self.logger.info("Re-run onboarding requested")
            appState.restartOnboarding()
        }
        .help("Restart the setup flow from the beginning")
        .padding(.top, Theme.spacing.md)
    }

    // MARK: - Shared

    private var divider: some View {
        Divider()
            .overlay(Theme.color.surfaceStroke)
            .padding(.vertical, Theme.spacing.xs)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .frame(width: 720, height: 640)
        .preferredColorScheme(.dark)
}
