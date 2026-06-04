//
//  Local402Markdown.swift
//  Local402
//
//  Lightweight Markdown renderer for assistant replies. The model emits Markdown
//  (**bold**, *italic*, `code`, # headings, - / 1. lists, ``` fences, > quotes),
//  and plain `Text` showed those markers verbatim. This parses the text into
//  block elements and renders each with the app's theme; inline spans are handled
//  by AttributedString's Markdown parser in `.inlineOnlyPreservingWhitespace`
//  mode, which keeps the newlines/whitespace the streaming path depends on.
//
//  Built for streaming: parsing is line-based and cheap enough to re-run on every
//  token, and an unterminated ``` fence is rendered as an open code block so code
//  formats as it arrives. Unbalanced inline markers (e.g. a `**` whose closer
//  hasn't streamed yet) are left as literal text until the closer lands.
//

import SwiftUI

struct Local402Markdown: View {
    let text: String
    /// Base color for body/heading/list text (links keep their own color).
    var textColor: Color = Theme.color.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            ForEach(Array(Block.parse(text).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let content):
            inlineText(content)
                .font(Self.headingFont(level))
                .foregroundStyle(textColor)
                .lineSpacing(3)
                .padding(.top, level <= 2 ? 2 : 0)

        case .paragraph(let content):
            inlineText(content)
                .font(Theme.font.body)
                .foregroundStyle(textColor)
                .lineSpacing(6)

        case .bullet(let content):
            listRow(marker: "•", content: content, markerColor: Theme.color.accent)

        case .numbered(let number, let content):
            listRow(marker: "\(number).", content: content, markerColor: Theme.color.textSecondary)

        case .quote(let content):
            HStack(alignment: .top, spacing: Theme.spacing.sm) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Theme.color.accent.opacity(0.6))
                    .frame(width: 3)
                inlineText(content)
                    .font(Theme.font.body)
                    .foregroundStyle(Theme.color.textSecondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let code):
            Text(code)
                .font(Theme.font.mono)
                .foregroundStyle(Theme.color.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                        .fill(Theme.color.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius.sm, style: .continuous)
                        .stroke(Theme.color.surfaceStroke, lineWidth: 1)
                )

        case .rule:
            Rectangle()
                .fill(Theme.color.surfaceStroke)
                .frame(height: 1)
                .padding(.vertical, 2)
        }
    }

    private func listRow(marker: String, content: String, markerColor: Color) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing.sm) {
            Text(marker)
                .font(Theme.font.body)
                .foregroundStyle(markerColor)
                .frame(minWidth: 16, alignment: .leading)
            inlineText(content)
                .font(Theme.font.body)
                .foregroundStyle(textColor)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Inline Markdown (bold/italic/code/links) parsed into a `Text`.
    private func inlineText(_ content: String) -> Text {
        Text(Self.inlineAttributed(content))
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 19, weight: .semibold)
        case 2: return .system(size: 16, weight: .semibold)
        default: return .system(size: 14, weight: .semibold)
        }
    }

    /// Parses a single line/paragraph's inline Markdown, preserving whitespace so
    /// soft line breaks survive. Falls back to the raw string if parsing fails.
    private static func inlineAttributed(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return attributed
        }
        return AttributedString(string)
    }
}

// MARK: - Block model + parser

private enum Block: Equatable {
    case heading(level: Int, content: String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case code(String)
    case rule

    /// Line-based parse of Markdown into renderable blocks. Consecutive plain
    /// lines coalesce into one paragraph (newlines preserved); blank lines break
    /// paragraphs. Tolerant of partial input for streaming.
    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }
        func flushCode() {
            blocks.append(.code(codeLines.joined(separator: "\n")))
            codeLines.removeAll()
        }

        for rawLine in text.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Fenced code block toggling (```), ignoring any language hint.
            if trimmed.hasPrefix("```") {
                if inCode { inCode = false; flushCode() }
                else { flushParagraph(); inCode = true }
                continue
            }
            if inCode { codeLines.append(rawLine); continue }

            if trimmed.isEmpty { flushParagraph(); continue }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph(); blocks.append(.rule); continue
            }
            if let heading = heading(trimmed) {
                flushParagraph(); blocks.append(heading); continue
            }
            if let bullet = bullet(trimmed) {
                flushParagraph(); blocks.append(.bullet(bullet)); continue
            }
            if let (number, content) = numbered(trimmed) {
                flushParagraph(); blocks.append(.numbered(number, content)); continue
            }
            if trimmed.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
                continue
            }

            paragraph.append(trimmed)
        }

        if inCode { flushCode() }   // unterminated fence (streaming in progress)
        flushParagraph()
        return blocks
    }

    /// ATX heading: 1–6 leading `#` followed by a space. `#tag` is not a heading.
    private static func heading(_ line: String) -> Block? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", level < 6 {
            level += 1
            index = line.index(after: index)
        }
        guard index < line.endIndex, line[index] == " " else { return nil }
        let content = String(line[index...]).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, content: content)
    }

    /// Unordered list marker `- `, `* `, or `+ ` (the trailing space distinguishes
    /// a bullet from `*italic*` / `**bold**`).
    private static func bullet(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// Ordered list marker `1. ` … `999. `.
    private static func numbered(_ line: String) -> (Int, String)? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let rest = line[digits.endIndex...]
        guard rest.hasPrefix(". ") else { return nil }
        return (number, String(rest.dropFirst(2)))
    }
}

#Preview {
    ZStack {
        Theme.color.background.ignoresSafeArea()
        ScrollView {
            Local402Markdown(text: """
                ## Quarterly summary

                Revenue is **up 12%** this quarter, driven by *enterprise* deals. \
                Key drivers:

                - New logos in the `EMEA` region
                - Expansion in existing accounts
                1. Renewals closed early
                2. Upsell on the Pro tier

                > Net: the trend is clearly upward.

                ```
                growth = (q3 - q2) / q2
                ```
                """)
            .padding(Theme.spacing.xl)
        }
    }
    .frame(width: 620, height: 460)
    .preferredColorScheme(.dark)
}
