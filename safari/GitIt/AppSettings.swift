import Foundation
import Observation
import ServiceManagement

/// The facilitator-facing settings, backed by UserDefaults (and SMAppService for login).
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    static let intervalChoices = [1, 2, 5, 10, 15, 30, 60]
    static let popupCountChoices = [3, 5, 10, 15]

    private let defaults = UserDefaults.standard

    private enum Key {
        static let mute = "muteNotifications"
        static let system = "showSystemNotifications"
        static let interval = "checkIntervalMinutes"
        static let popupCount = "popupItemCount"
        static let menuBar = "showMenuBarIcon"
        static let menuBarStyle = "menuBarIconStyle"
    }

    /// How many items each tab of the Safari popup lists.
    var popupItemCount: Int {
        didSet { defaults.set(popupItemCount, forKey: Key.popupCount) }
    }

    /// Whether GitIt has an item in the menu bar. Off, the app runs with no visible UI;
    /// opening it again from Finder or Spotlight brings the settings window back.
    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Key.menuBar) }
    }

    var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Key.menuBarStyle) }
    }

    var muteNotifications: Bool {
        didSet { defaults.set(muteNotifications, forKey: Key.mute) }
    }

    var showSystemNotifications: Bool {
        didSet { defaults.set(showSystemNotifications, forKey: Key.system) }
    }

    var checkIntervalMinutes: Int {
        didSet { defaults.set(checkIntervalMinutes, forKey: Key.interval) }
    }

    /// Mirrors SMAppService; setting it registers or unregisters the app as a login item.
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private(set) var launchAtLoginError: String?

    private init() {
        defaults.register(defaults: [
            Key.mute: false,
            Key.system: true,
            Key.interval: 1,
            Key.popupCount: 5,
            Key.menuBar: true,
        ])
        showMenuBarIcon = defaults.bool(forKey: Key.menuBar)
        menuBarIconStyle = defaults.string(forKey: Key.menuBarStyle).flatMap(MenuBarIconStyle.init) ?? .count
        muteNotifications = defaults.bool(forKey: Key.mute)
        showSystemNotifications = defaults.bool(forKey: Key.system)
        let stored = defaults.integer(forKey: Key.interval)
        checkIntervalMinutes = Self.intervalChoices.contains(stored) ? stored : 1
        let storedCount = defaults.integer(forKey: Key.popupCount)
        popupItemCount = Self.popupCountChoices.contains(storedCount) ? storedCount : 5
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Re-reads the login item state, which System Settings can change behind our back.
    func refreshLaunchAtLogin() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != launchAtLogin { launchAtLogin = enabled }
    }

    static func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 1: return "1 minute"
        case 60: return "1 hour"
        default: return "\(minutes) minutes"
        }
    }
}
