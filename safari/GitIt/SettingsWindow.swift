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
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
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
