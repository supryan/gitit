import AppKit
import SwiftUI

/// The status colours, shared with the Safari extension's popup and dashboard
/// (`GitIt Extension/theme.css`); change them in both places.
extension AttentionItem.Kind {
    var nsColor: NSColor {
        switch self {
        case .reviewRequest: Self.dynamic(light: 0x8B5CF6, dark: 0xA78BFA)
        case .assigned: Self.dynamic(light: 0x16A34A, dark: 0x4ADE80)
        case .pullRequest: Self.dynamic(light: 0x2F7CF6, dark: 0x60A5FA)
        case .notification: Self.dynamic(light: 0xF97316, dark: 0xFB923C)
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    private static func dynamic(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }
}
