import SwiftUI

@main
struct GitItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var settings = AppSettings.shared

    var body: some Scene {
        Window("GitIt", id: "main") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Also flips off if the user ⌘-drags the item out of the menu bar.
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            MenuBarView()
        } label: {
            MenuBarLabel()
        }
    }
}
