import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opens the settings window. SwiftUI owns openWindow, so the views hand it over here;
    /// reopening needs it when the window is gone and there is no menu bar item to use.
    static var openSettings: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.shared.prepare()
        Monitor.shared.start()

        // Launched at login: stay in the menu bar and keep the window closed. Launched
        // by hand (Finder, Spotlight): show the settings window.
        if launchedAsLoginItem {
            DispatchQueue.main.async {
                NSApp.windows.filter { $0.canBecomeKey }.forEach { $0.close() }
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopened from the Dock or Finder while running: bring the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                Self.openSettings?()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEOpenApplication,
              let reason = event.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return reason.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
