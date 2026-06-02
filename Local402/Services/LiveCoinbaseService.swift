//
//  LiveCoinbaseService.swift
//  Local402
//
//  URLSession-based REST client that talks to the backend-for-frontend (BFF)
//  at `CoinbaseConfig.bffURL`. All secrets live on the BFF; this client only
//  forwards public, already-authorized requests. Monetary amounts are encoded
//  on the wire as decimal strings to avoid binary-floating-point drift.
//

import Foundation
import os

/// Live implementation of `CoinbaseServicing` backed by the BFF REST API.
final class LiveCoinbaseService: CoinbaseServicing {
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "tech.hiant.Local402", category: "LiveCoinbaseService")

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = CoinbaseConfig.bffURL, session: URLSession? = nil) {
        self.baseURL = baseURL

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - CoinbaseServicing

    func createServerWallet() async throws -> ServerWallet {
        let response: CreateWalletResponse = try await post(
            path: "wallet/create",
            body: EmptyBody()
        )
        return ServerWallet(address: response.address, walletId: response.walletId)
    }

    func balance(of address: String) async throws -> Decimal {
        let escaped = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? address
        let response: BalanceResponse = try await get(path: "wallet/\(escaped)/balance")
        guard let usdc = DecimalString.decimal(from: response.usdc) else {
            logger.error("Failed to parse balance string '\(response.usdc, privacy: .public)'")
            throw CoinbaseServiceError.decoding
        }
        return usdc
    }

    func fund(address: String, amountUSD: Decimal, applePayToken: Data?) async throws -> FundReceipt {
        let body = FundRequest(
            address: address,
            amountUSD: DecimalString.string(from: amountUSD),
            applePayToken: applePayToken?.base64EncodedString()
        )
        let response: FundResponse = try await post(path: "fund", body: body)
        guard let credited = DecimalString.decimal(from: response.creditedUSD) else {
            logger.error("Failed to parse creditedUSD string '\(response.creditedUSD, privacy: .public)'")
            throw CoinbaseServiceError.decoding
        }
        return FundReceipt(txHash: response.txHash, creditedUSD: credited)
    }

    func payX402(_ envelope: X402Envelope, from address: String) async throws -> PaymentReceipt {
        let body = PayRequest(
            resource: envelope.resource,
            label: envelope.label,
            amount: DecimalString.string(from: envelope.amount),
            from: address
        )
        let response: PayResponse = try await post(path: "x402/pay", body: body)
        guard let amount = DecimalString.decimal(from: response.amount) else {
            logger.error("Failed to parse payment amount string '\(response.amount, privacy: .public)'")
            throw CoinbaseServiceError.decoding
        }
        return PaymentReceipt(
            txHash: response.txHash,
            amount: amount,
            resource: response.resource,
            label: response.label
        )
    }

    func search(_ query: String) async throws -> WebSearchResult {
        let body = SearchRequest(query: query)
        // Tavily search can take a few seconds (live web crawl + facilitator
        // settlement), so allow a more generous per-request timeout than the
        // session default.
        let response: SearchResponse = try await post(
            path: "tools/search",
            body: body,
            timeout: 60
        )

        // The wire `amount` is the canonical decimal string for the price paid
        // (e.g. "0.010000"). Parse it through the same helper used elsewhere so
        // the pill/spend chip reflect the real on-chain debit.
        guard let amount = DecimalString.decimal(from: response.amount) else {
            logger.error("Failed to parse search amount string '\(response.amount, privacy: .public)'")
            throw CoinbaseServiceError.decoding
        }

        let payment = PaymentReceipt(
            txHash: response.txHash,
            amount: amount,
            resource: "x402.tavily.com/search",
            label: "Tavily search"
        )

        let hits = response.results.map { result in
            SearchHit(
                title: result.title,
                url: result.url,
                content: result.content,
                score: result.score
            )
        }

        return WebSearchResult(
            query: response.query,
            answer: response.answer,
            hits: hits,
            payment: payment
        )
    }

    // MARK: - Transport

    private func get<Response: Decodable>(path: String) async throws -> Response {
        let request = makeRequest(path: path, method: "GET", httpBody: nil)
        return try await perform(request)
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        timeout: TimeInterval? = nil
    ) async throws -> Response {
        let httpBody: Data
        do {
            httpBody = try encoder.encode(body)
        } catch {
            logger.error("Failed to encode request body for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw CoinbaseServiceError.decoding
        }
        let request = makeRequest(path: path, method: "POST", httpBody: httpBody, timeout: timeout)
        return try await perform(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        httpBody: Data?,
        timeout: TimeInterval? = nil
    ) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let httpBody {
            request.httpBody = httpBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let timeout {
            request.timeoutInterval = timeout
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            let message = error.localizedDescription
            logger.error("Transport error for \(request.url?.absoluteString ?? "?", privacy: .public): \(message, privacy: .public)")
            throw CoinbaseServiceError.transport(message)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            logger.error("Non-HTTP response received")
            throw CoinbaseServiceError.transport("Non-HTTP response")
        }

        guard (200...299).contains(http.statusCode) else {
            logger.error("HTTP \(http.statusCode) from \(request.url?.absoluteString ?? "?", privacy: .public)")
            throw CoinbaseServiceError.http(http.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            logger.error("Decoding error for \(request.url?.absoluteString ?? "?", privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw CoinbaseServiceError.decoding
        }
    }
}

// MARK: - Decimal <-> String helper

/// Converts between `Decimal` and the canonical decimal-string wire format.
/// Monetary amounts cross the wire as strings to avoid IEEE-754 rounding.
private enum DecimalString {
    /// Parses a wire string (e.g. "12.34") into a `Decimal`, rejecting NaN.
    static func decimal(from string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // `Decimal(string:locale:)` with a fixed POSIX locale ensures '.' is the
        // decimal separator regardless of the device locale.
        let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
        guard let value, !value.isNaN else { return nil }
        return value
    }

    /// Renders a `Decimal` as a locale-independent wire string.
    static func string(from decimal: Decimal) -> String {
        var copy = decimal
        return NSDecimalString(&copy, Locale(identifier: "en_US_POSIX"))
    }
}

// MARK: - Wire DTOs

private struct EmptyBody: Encodable {}

private struct CreateWalletResponse: Decodable {
    let address: String
    let walletId: String
}

private struct BalanceResponse: Decodable {
    let address: String
    let usdc: String
}

private struct FundRequest: Encodable {
    let address: String
    let amountUSD: String
    let applePayToken: String?
}

private struct FundResponse: Decodable {
    let txHash: String
    let creditedUSD: String
}

private struct PayRequest: Encodable {
    let resource: String
    let label: String
    let amount: String
    let from: String
}

private struct PayResponse: Decodable {
    let txHash: String
    let amount: String
    let resource: String
    let label: String
}

private struct SearchRequest: Encodable {
    let query: String
}

private struct SearchResponse: Decodable {
    let query: String
    let answer: String?
    let results: [SearchResultDTO]
    let txHash: String
    /// Price paid, as a canonical decimal string (e.g. "0.010000").
    let amount: String
}

private struct SearchResultDTO: Decodable {
    let title: String
    let url: String
    let content: String
    let score: Double
}
