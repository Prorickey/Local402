//
//  MockChat.swift
//  Local402
//
//  Scripted assistant replies for the simulated chat, including inline
//  payment "beats" that drive wallet debits during streaming.
//

import Foundation

/// A payment the agent decides to make mid-reply.
struct PaymentBeat {
    let amount: Decimal
    let label: String
    let resource: String
}

/// One unit of a scripted reply: streamed text or a payment event.
enum ReplyBeat {
    case text(String)
    case payment(PaymentBeat)
}

enum MockChat {
    /// The assistant's opening message when the chat first loads.
    static func greeting(modelName: String) -> [ReplyBeat] {
        [
            .text("I'm running locally on \(modelName) with your company files loaded for context. "),
            .text("Ask me anything — paid tools like Tavily web search are weighed against their cost, and payments settle over x402 through your Coinbase wallet. I'll always tell you what I spend.")
        ]
    }

    /// Scripted replies cycled through as the user sends messages.
    static let replies: [[ReplyBeat]] = [
        [
            .text("Let me search the web with Tavily for that. "),
            .payment(PaymentBeat(amount: 0.02, label: "Tavily search", resource: "api.tavily.com/search")),
            .text("Based on three recent results, the trend is clearly upward this quarter. "),
            .text("That single search was worth it — the cached data I had was two weeks stale.")
        ],
        [
            .text("I can answer this directly from your loaded handbook — no external call needed, so this one's free. "),
            .text("The policy allows up to 20 days of carryover, prorated by start date.")
        ],
        [
            .text("This needs fresh market data. "),
            .payment(PaymentBeat(amount: 0.12, label: "Market data feed", resource: "data.finance.io/quote")),
            .text("Got it. "),
            .text("I also want to double-check the filing against a primary source. "),
            .payment(PaymentBeat(amount: 0.05, label: "Document lookup", resource: "edgar.sec.gov/fetch")),
            .text("Confirmed — the numbers reconcile. Total spend on this answer: $0.17, which is well under the value of getting it right.")
        ],
        [
            .text("I'll run that snippet to be sure it behaves as expected. "),
            .payment(PaymentBeat(amount: 0.03, label: "Code execution", resource: "sandbox.run/exec")),
            .text("It returns the expected output and handles the empty-input edge case correctly.")
        ],
        [
            .text("That's a judgment call I can make locally from the context you gave me — skipping any paid tools here. "),
            .text("My recommendation: ship the smaller change first, measure, then decide on the rest.")
        ]
    ]

    /// Returns the reply for the given user-message count (1-based), cycling through the list.
    static func reply(forUserTurn turn: Int) -> [ReplyBeat] {
        guard !replies.isEmpty else { return [.text("Understood.")] }
        let index = (max(1, turn) - 1) % replies.count
        return replies[index]
    }
}
