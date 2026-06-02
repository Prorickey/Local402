//
//  ConversationGrouping.swift
//  Local402
//
//  Groups conversation summaries into relative-day buckets ("Today", "Yesterday",
//  "Previous 7 days", "Older") for the history sidebar, ordered most-recent-first
//  within each bucket. Pure, calendar-driven, and side-effect free.
//

import Foundation

/// A named, ordered bucket of conversation summaries for sidebar display.
struct ConversationGroup: Identifiable, Hashable {
    let title: String
    let items: [ConversationSummary]

    var id: String { title }
}

enum ConversationGrouping {
    /// Buckets summaries by `updatedAt` relative to `now`, preserving the
    /// most-recent-first order and emitting only non-empty groups.
    static func groups(
        from summaries: [ConversationSummary],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ConversationGroup] {
        let sorted = summaries.sorted { $0.updatedAt > $1.updatedAt }

        var today: [ConversationSummary] = []
        var yesterday: [ConversationSummary] = []
        var previous7: [ConversationSummary] = []
        var older: [ConversationSummary] = []

        let startOfToday = calendar.startOfDay(for: now)

        for summary in sorted {
            switch bucket(for: summary.updatedAt, startOfToday: startOfToday, calendar: calendar) {
            case .today: today.append(summary)
            case .yesterday: yesterday.append(summary)
            case .previous7: previous7.append(summary)
            case .older: older.append(summary)
            }
        }

        let named: [(String, [ConversationSummary])] = [
            ("TODAY", today),
            ("YESTERDAY", yesterday),
            ("PREVIOUS 7 DAYS", previous7),
            ("OLDER", older),
        ]

        return named
            .filter { !$0.1.isEmpty }
            .map { ConversationGroup(title: $0.0, items: $0.1) }
    }

    private enum Bucket {
        case today
        case yesterday
        case previous7
        case older
    }

    private static func bucket(
        for date: Date,
        startOfToday: Date,
        calendar: Calendar
    ) -> Bucket {
        if calendar.isDate(date, inSameDayAs: startOfToday) { return .today }

        guard let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: startOfToday).day else {
            return .older
        }

        if dayOffset == 1 { return .yesterday }
        if dayOffset <= 7 { return .previous7 }
        return .older
    }
}
