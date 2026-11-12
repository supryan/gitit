import Foundation

/// GitIt's bundle id was com.jickfive.gitit; it is com.gitit.app now. Settings and the
/// token are kept per bundle id, so on the first launch under the new id this copies
/// them across once: the settings from the old preferences, and the token from the old
/// keychain entry (macOS may ask once whether GitIt may read it).
enum Migration {
    private static let legacyID = "com.jickfive.gitit"
    private static let doneKey = "migratedFromLegacyBundleID"

    /// Settings and notification bookkeeping that live in the app's own preferences.
    private static let keys = [
        "muteNotifications", "showSystemNotifications", "checkIntervalMinutes", "popupItemCount",
        "showMenuBarIcon", "menuBarIconStyle", "seenItemIds", "seenItemsPrimed", "lastCheckedAt",
    ]

    /// Runs before anything reads the settings or the token.
    static func run() {
        let defaults = UserDefaults.standard
        guard Bundle.main.bundleIdentifier != legacyID, !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)

        if let old = UserDefaults(suiteName: legacyID) {
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
            }
        }
        if Keychain.token == nil, let token = Keychain.token(service: legacyID), !token.isEmpty {
            try? Keychain.save(token)
        }
    }
}
