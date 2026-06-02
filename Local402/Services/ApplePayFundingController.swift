//
//  ApplePayFundingController.swift
//  Local402
//
//  Presents the native PassKit Apple Pay sheet (no popup / web view) and bridges
//  its delegate callbacks to async/await. The actual fiat capture is mocked: the
//  authorized payment token is handed to a `settle` closure (BFF treasury USDC
//  transfer) which returns the on-chain tx hash. Nothing here holds secrets.
//

import AppKit
import Foundation
import PassKit
import os

/// Drives a single Apple Pay authorization and forwards the resulting token to a
/// settlement closure. Lives on the main actor (PassKit UI must be main-actor).
@MainActor
final class ApplePayFundingController: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "ApplePayFundingController")

    /// In-flight continuation for the current authorization. Set while a sheet is
    /// presented; consumed exactly once (guarded against double-resume).
    private var continuation: CheckedContinuation<String, Error>?

    /// Settlement closure for the active flow: token -> tx hash. Captured for the
    /// `didAuthorizePayment` delegate callback.
    private var settle: ((Data) async throws -> String)?

    /// The tx hash captured during `didAuthorizePayment`, resolved in `didFinish`
    /// once the sheet has fully dismissed.
    private var settledTxHash: String?

    /// Set true once `didAuthorizePayment` ran (success or failure), so `didFinish`
    /// can distinguish a user cancellation from a completed authorization.
    private var didAuthorize = false

    /// Settlement error captured during authorization, surfaced from `didFinish`.
    private var settlementError: Error?

    /// Whether Apple Pay is usable on this device/account.
    static func canMakePayments() -> Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }

    /// Presents the Apple Pay sheet for `amountUSD`, runs `settle` with the
    /// authorized token, and returns the settlement tx hash.
    ///
    /// - Throws: `CoinbaseServiceError.applePayUnavailable` if Apple Pay can't be
    ///   used, `.applePayCancelled` if the user dismisses the sheet, or any error
    ///   thrown by `settle`.
    func fund(
        amountUSD: Decimal,
        settle: @escaping (_ applePayToken: Data) async throws -> String
    ) async throws -> String {
        guard Self.canMakePayments() else {
            logger.error("Apple Pay unavailable on this device")
            throw CoinbaseServiceError.applePayUnavailable
        }

        // Reset per-flow state.
        self.settle = settle
        self.settledTxHash = nil
        self.settlementError = nil
        self.didAuthorize = false

        let request = Self.makePaymentRequest(amountUSD: amountUSD)
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self

        do {
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                self.continuation = cont
                controller.present { presented in
                    Task { @MainActor in
                        guard !presented else { return }
                        self.logger.error("Apple Pay sheet failed to present")
                        self.resume(throwing: CoinbaseServiceError.applePayUnavailable)
                    }
                }
            }
        } catch {
            // Ensure no dangling references after a failed flow.
            self.settle = nil
            throw error
        }
    }

    // MARK: - Request building

    private static func makePaymentRequest(amountUSD: Decimal) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = CoinbaseConfig.merchantID
        request.merchantCapabilities = .threeDSecure
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.countryCode = "US"
        request.currencyCode = CoinbaseConfig.currencyCode
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "Local402 wallet funding",
                amount: NSDecimalNumber(decimal: amountUSD)
            )
        ]
        return request
    }

    // MARK: - Continuation safety

    /// Resolves the in-flight continuation exactly once.
    private func resume(returning value: String) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: value)
    }

    /// Rejects the in-flight continuation exactly once.
    private func resume(throwing error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: error)
    }

    // MARK: - PKPaymentAuthorizationControllerDelegate

    /// macOS requires a window to anchor the Apple Pay sheet. Return the app's
    /// key (or first visible) window.
    func presentationWindow(for controller: PKPaymentAuthorizationController) -> NSWindow? {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        didAuthorize = true
        let token = payment.token.paymentData
        let settle = self.settle

        Task { @MainActor in
            guard let settle else {
                self.settlementError = CoinbaseServiceError.notReady
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            do {
                let txHash = try await settle(token)
                self.settledTxHash = txHash
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } catch {
                self.logger.error("Apple Pay settlement failed: \(error.localizedDescription, privacy: .public)")
                self.settlementError = error
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            Task { @MainActor in
                self.settle = nil
                defer {
                    self.settledTxHash = nil
                    self.settlementError = nil
                    self.didAuthorize = false
                }

                if !self.didAuthorize {
                    // Sheet dismissed without an authorization → user cancelled.
                    self.logger.debug("Apple Pay cancelled by user")
                    self.resume(throwing: CoinbaseServiceError.applePayCancelled)
                    return
                }
                if let error = self.settlementError {
                    self.resume(throwing: error)
                    return
                }
                if let txHash = self.settledTxHash {
                    self.resume(returning: txHash)
                    return
                }
                // Authorized but no hash and no error — treat as a failure.
                self.resume(throwing: CoinbaseServiceError.notReady)
            }
        }
    }
}
