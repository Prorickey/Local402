//
//  Color+Hex.swift
//  Local402
//
//  Hex initializer for SwiftUI Color.
//

import SwiftUI

extension Color {
    /// Creates a color from a hex string such as `"#1B2640"` or `"1B2640"`.
    /// Supports 6-digit (RGB) and 8-digit (ARGB) hex values. Falls back to clear on malformed input.
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value) else {
            self = .clear
            return
        }

        let r, g, b, a: Double
        switch sanitized.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8:
            a = Double((value & 0xFF000000) >> 24) / 255
            r = Double((value & 0x00FF0000) >> 16) / 255
            g = Double((value & 0x0000FF00) >> 8) / 255
            b = Double(value & 0x000000FF) / 255
        default:
            self = .clear
            return
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
