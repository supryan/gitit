import SwiftUI

/// The app runs from its delegate: the menu bar item (StatusItem.swift) and the settings
/// window (SettingsWindow.swift) are AppKit. SwiftUI still provides the app lifecycle and
/// the standard menus, which give the token field ⌘V and the other edit shortcuts.
@main
struct GitItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // A scene is required; this one never opens a window.
        Settings { EmptyView() }
            .commandsRemoved()
    }
}
