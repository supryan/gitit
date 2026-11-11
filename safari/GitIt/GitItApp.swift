import SwiftUI

@main
struct GitItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("GitIt", id: "main") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarLabel()
        }
    }
}
