import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        Migration.run()
        // Before launch finishes, so a notification click that launched GitIt is delivered.
        Notifier.shared.prepare()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Monitor.shared.start()
        ChromeExtension.shared.updateIfInstalled()
        StatusItemController.shared.start()

        // Launched by hand (Finder, Spotlight): show the settings window. Launched at
        // login, or by a notification click (which opens its link instead): stay out of
        // the way. Not every notification launch says so in userInfo, but the click
        // arrives just after launch, hence the short wait.
        let fromNotification = notification.userInfo?[NSApplication.launchUserNotificationUserInfoKey] != nil
        guard !launchedAsLoginItem, !fromNotification else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !Notifier.shared.respondedRecently { SettingsWindow.shared.show() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopened from Finder or Spotlight while running: bring the window back. Clicking
    /// one of GitIt's notifications reopens the app too, so wait a moment to see whether
    /// a click arrives; a click only opens its link in the browser.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !Notifier.shared.respondedRecently { SettingsWindow.shared.show() }
        }
        return false
    }

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEOpenApplication,
              let reason = event.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return reason.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
