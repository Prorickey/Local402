//
//  PaymentRow.swift
//  Local402
//
//  A single row in the recent-payments list: leading payment icon, label and
//  resource, trailing amount in green with a relative timestamp.
//

import SwiftUI

struct PaymentRow: View {
    let payment: PaymentEvent

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            iconBadge
            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text(payment.label)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textPrimary)
                    .lineLimit(1)
                Text(payment.resource)
                    .font(Theme.font.mono)
                    .foregroundStyle(Theme.color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Theme.spacing.md)
            VStack(alignment: .trailing, spacing: Theme.spacing.xs) {
                Text(payment.amountLabel)
                    .font(Theme.font.headline)
                    .foregroundStyle(Theme.color.paymentGreen)
                    .monospacedDigit()
                Text(relativeTime)
                    .font(Theme.font.caption)
                    .foregroundStyle(Theme.color.textTertiary)
            }
        }
        .padding(.vertical, Theme.spacing.xs)
        .help("x402 payment to \(payment.resource)")
    }

    // MARK: - Components

    private var iconBadge: some View {
        Image(systemName: "creditcard.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.color.paymentGreen)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Theme.color.paymentGreenSoft))
    }

    // MARK: - Derived values

    private var relativeTime: String {
        payment.timestamp.formatted(.relative(presentation: .named))
    }
}

#Preview {
    let payments = MockWallet.seedPayments(now: Date())
    return ZStack {
        Theme.color.background.ignoresSafeArea()
        VStack(spacing: Theme.spacing.md) {
            ForEach(payments.prefix(3)) { payment in
                PaymentRow(payment: payment)
            }
        }
        .padding(Theme.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.lg, style: .continuous)
                .fill(Theme.color.surface)
        )
        .padding(Theme.spacing.xl)
    }
    .frame(width: 560)
    .preferredColorScheme(.dark)
}
