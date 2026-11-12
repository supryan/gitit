import SwiftUI

/// Where GitIt starts. Chrome launches the same executable as the Chrome extension's
/// native messaging host (ChromeNativeHost.swift); that answers and exits without any UI.
/// Otherwise it is the app.
@main
@MainActor
enum Entry {
    static func main() {
        if ChromeNativeHost.isRequested {
            ChromeNativeHost.run()
            return
        }
        GitItApp.main()
    }
}

/// The app runs from its delegate: the menu bar item (StatusItem.swift) and the settings
/// window (SettingsWindow.swift) are AppKit. SwiftUI still provides the app lifecycle and
/// the standard menus, which give the token field ⌘V and the other edit shortcuts.
struct GitItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // A scene is required; this one never opens a window.
        Settings { EmptyView() }
            .commandsRemoved()
    }
}
