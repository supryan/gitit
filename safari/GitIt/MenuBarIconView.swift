import AppKit
import SwiftUI

/// How the menu bar item shows the count.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case count, badge, dot, plain

    var id: String { rawValue }

    var name: String {
        switch self {
        case .count: "Count"
        case .badge: "Badge"
        case .dot: "Dot"
        case .plain: "Icon only"
        }
    }
}

/// The menu bar item's content, also used for the previews in Settings so they match.
struct MenuBarIconView: View {
    let style: MenuBarIconStyle
    let count: Int

    var body: some View {
        switch style {
        case .count:
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                tray
                if count > 0 {
                    Text(label)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.7)
                }
            }

        case .badge:
            tray
                .padding(.top, 3)
                .padding(.trailing, count > 0 ? 6 : 0)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(label)
                            .font(.system(size: 8.5, weight: .bold))
                            .monospacedDigit()
                            .tracking(-0.9)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 13, minHeight: 13)
                            .background(Color.red, in: Capsule())
                            .offset(x: 2, y: -2)
                    }
                }

        case .dot:
            // The app icon in monochrome: a dot punched into the tray's corner.
            Image(systemName: "tray")
                .font(.system(size: 15, weight: .medium))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        ZStack {
                            Circle().fill(.black).blendMode(.destinationOut)
                                .frame(width: 9.5, height: 9.5)
                            Circle().fill(.primary)
                                .frame(width: 6, height: 6)
                        }
                        .offset(x: 2.5, y: -2)
                    }
                }
                .compositingGroup()

        case .plain:
            tray
        }
    }

    private var tray: some View {
        Image(systemName: count > 0 ? "tray.full" : "tray")
            .font(.system(size: 15, weight: .medium))
    }

    private var label: String {
        count > 999 ? "999+" : String(count)
    }
}

/// Hosts the SwiftUI icon inside the status item's button and lets clicks fall through
/// to the button, which opens the menu.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The style picker in Settings: a live preview of each style, the chosen one outlined.
struct MenuBarStylePicker: View {
    @Binding var selection: MenuBarIconStyle

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MenuBarIconStyle.allCases) { style in
                let selected = style == selection
                Button {
                    selection = style
                } label: {
                    VStack(spacing: 6) {
                        MenuBarIconView(style: style, count: 12)
                            .frame(height: 24)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        Text(style.name)
                            .font(.caption)
                            .foregroundStyle(selected ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
