import AppKit
import Observation

/// The Chrome extension, from the app's side: whether Chrome is on this Mac, whether GitIt
/// has set the extension up, and whether Chrome has loaded it. Settings' Chrome row and the
/// Dashboard button read this.
///
/// GitIt carries the built extension ("GitIt for Chrome" in its resources). Install copies it
/// to Application Support and registers GitIt's native messaging host with Chrome. Chrome only
/// loads an unpacked extension the user picks, so Settings then walks them through that.
@MainActor
@Observable
final class ChromeExtension {
    static let shared = ChromeExtension()

    /// Pinned by the key in chrome/manifest.json.
    static let id = "mgcnmhlmcnjpabbdcpoflcejlojpmoap"
    static let bundleID = "com.google.Chrome"

    enum State: Equatable {
        /// Chrome is not installed.
        case noChrome
        /// GitIt has not put the extension in place yet.
        case notInstalled
        /// In place, but Chrome has not loaded it (or not recently, while running).
        case notLoaded
        /// Chrome's extension talks to GitIt.
        case enabled
    }

    private(set) var state: State = .notInstalled

    /// Where Install puts the unpacked extension; Chrome loads it from here.
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GitIt/GitIt for Chrome", isDirectory: true)

    private static let hostsFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts", isDirectory: true)
    private static let hostManifest = hostsFolder.appendingPathComponent("com.gitit.app.json")

    var chromeURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) }

    private var shared: UserDefaults? { Monitor.appGroup.flatMap(UserDefaults.init(suiteName:)) }

    private init() { refresh() }

    /// Re-reads the state. Cheap; runs with every check and when Settings comes forward.
    func refresh() {
        guard chromeURL != nil else {
            state = .noChrome
            return
        }
        // The extension checks in every minute while Chrome runs (ChromeNativeHost records
        // it), wherever it was loaded from. Seen before and Chrome is closed: still enabled.
        if let seen = shared?.object(forKey: "chromeLastSeen") as? Double {
            let recent = Date().timeIntervalSince1970 - seen < 180
            let running = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
            if recent || !running {
                state = .enabled
                return
            }
        }
        let installed = FileManager.default.fileExists(atPath: Self.folder.appendingPathComponent("manifest.json").path)
        state = installed ? .notLoaded : .notInstalled
    }

    /// Registers GitIt's native host with Chrome, pointing at this copy of GitIt. Runs at
    /// every launch when Chrome is here, so an extension loaded any way (Install, or a
    /// developer's `make chrome` build) always finds the app, under its current name.
    func registerHost() {
        guard chromeURL != nil else { return }
        try? writeHostManifest()
    }

    /// Puts the extension in place and registers GitIt's native host with Chrome.
    func install() throws {
        guard let bundled = Bundle.main.url(forResource: "GitIt for Chrome", withExtension: nil) else {
            throw InstallError("This copy of GitIt was built without the Chrome extension.")
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: Self.folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: Self.folder.path) {
            try fileManager.removeItem(at: Self.folder)
        }
        try fileManager.copyItem(at: bundled, to: Self.folder)
        try writeHostManifest()
        refresh()
    }

    /// At launch: registers the host, and after GitIt itself is updated refreshes an
    /// installed extension (Chrome reloads an unpacked extension's files when it starts).
    func updateIfInstalled() {
        registerHost()
        guard FileManager.default.fileExists(atPath: Self.folder.path) else { return }
        try? install()
    }

    private func writeHostManifest() throws {
        guard let executable = Bundle.main.executableURL?.path else {
            throw InstallError("GitIt could not find its own executable.")
        }
        let manifest: [String: Any] = [
            "name": "com.gitit.app",
            "description": "GitIt: hands the Chrome extension the GitIt app's latest result",
            "path": executable,
            "type": "stdio",
            "allowed_origins": ["chrome-extension://\(Self.id)/"],
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: Self.hostsFolder, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: Self.hostsFolder.appendingPathComponent("com.jickfive.gitit.json")) // old id
        try data.write(to: Self.hostManifest, options: .atomic)
    }

    // MARK: Opening things in Chrome

    /// Chrome's extensions page, scrolled to GitIt when it is loaded.
    func openExtensionsPage() {
        let address = state == .enabled ? "chrome://extensions/?id=\(Self.id)" : "chrome://extensions"
        open(URL(string: address))
    }

    /// The installed extension's folder, selected in Finder, ready to drag onto Chrome.
    func revealFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.folder])
    }

    func copyFolderPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.folder.path, forType: .string)
    }

    /// The Dashboard button chose Chrome. Chrome will not open an extension's page for
    /// another app, so this leaves a request and brings Chrome forward; a window gaining
    /// focus wakes the extension, which finds the request in its next status answer.
    func requestDashboard() {
        shared?.set(Date().timeIntervalSince1970, forKey: "chromeDashboardRequestedAt")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in open(nil) }
    }

    /// Opens `url` in Chrome, or just brings Chrome forward.
    private func open(_ url: URL?) {
        guard let chrome = chromeURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let url {
            NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: chrome, configuration: configuration)
        }
    }

    struct InstallError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
