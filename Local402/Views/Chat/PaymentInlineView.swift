//
//  PaymentInlineView.swift
//  Local402
//
//  Inline green pill shown within an assistant message when the agent pays
//  for a tool/API call.
//

import SwiftUI

struct PaymentInlineView: View {
    let event: PaymentEvent

    var body: some View {
        HStack(spacing: Theme.spacing.sm) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Paid \(event.amountLabel)")
                .fontWeight(.semibold)
            Text("·")
                .foregroundStyle(Theme.color.paymentGreen.opacity(0.6))
            Text(event.label)
            Text(event.resource)
                .font(Theme.font.mono)
                .foregroundStyle(Theme.color.paymentGreen.opacity(0.75))
        }
        .paymentPill()
        .help("x402 payment to \(event.resource)")
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        PaymentInlineView(
            event: PaymentEvent(
                amount: 0.02,
                label: "Web search",
                resource: "api.exa.ai/search",
                timestamp: Date()
            )
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 520)
    .preferredColorScheme(.dark)
}
