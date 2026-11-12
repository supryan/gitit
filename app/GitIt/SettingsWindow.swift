import AppKit
import SwiftUI

/// The app's one window, owned here rather than by a SwiftUI scene so the menu bar item,
/// a reopen from Finder, and launch can all show it the same way, and nothing opens it
/// on its own (a notification click must not).
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    func show() {
        let window = self.window ?? make()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func make() -> NSWindow {
        let window = EditingWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "GitIt"
        // The content draws its own header, so the title bar is just the traffic lights.
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}

/// Handles the standard editing shortcuts itself. They normally come from the Edit menu,
/// which GitIt does not have (it runs without a Dock icon or a menu bar of its own), so
/// without this ⌘V could not paste a token.
private final class EditingWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command || modifiers == [.command, .shift],
           let key = event.charactersIgnoringModifiers?.lowercased(),
           let action = Self.action(for: key, shift: modifiers.contains(.shift)),
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static func action(for key: String, shift: Bool) -> Selector? {
        switch (key, shift) {
        case ("x", false): return #selector(NSText.cut(_:))
        case ("c", false): return #selector(NSText.copy(_:))
        case ("v", false): return #selector(NSText.paste(_:))
        case ("a", false): return #selector(NSText.selectAll(_:))
        case ("z", false): return Selector(("undo:"))
        case ("z", true): return Selector(("redo:"))
        default: return nil
        }
    }
}
