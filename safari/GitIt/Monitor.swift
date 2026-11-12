import AppKit
import Foundation
import Observation
import SafariServices

/// Polls GitHub on the chosen interval, notifies about new items, and hands the summary
/// to the Safari extension through the app group.
@MainActor
@Observable
final class Monitor {
    static let shared = Monitor()

    /// Posted (as a distributed notification) by the extension's "Check now".
    static let refreshRequest = Notification.Name("com.jickfive.gitit.refresh")

    private(set) var summary: AttentionSummary?
    private(set) var isChecking = false
    private(set) var login: String?
    private(set) var hasToken = Keychain.token?.isEmpty == false

    private let settings = AppSettings.shared
    private let client = GitHubClient()
    private let notifier = Notifier.shared
    private var loop: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var activation: NSObjectProtocol?

    private let defaults = UserDefaults.standard
    private let seenKey = "seenItemIds"
    private let seenPrimedKey = "seenItemsPrimed"
    private let lastCheckKey = "lastCheckedAt"

    /// The suite shared with the extension; nil when the entitlement did not take.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "GitItAppGroup") as? String
    @ObservationIgnored private let shared: UserDefaults? = Monitor.appGroup.flatMap { UserDefaults(suiteName: $0) }

    var total: Int { summary?.total ?? 0 }

    /// The dashboard page, once the Safari extension has reported where it lives.
    var dashboardURL: URL? {
        shared?.string(forKey: "dashboardURL").flatMap(URL.init(string:))
    }

    /// Whether the dashboard can be opened: its address is known and the extension is on.
    /// Settings' button and the menu item are greyed out until then.
    private(set) var isDashboardReady = false

    private let extensionId = (Bundle.main.bundleIdentifier ?? "com.jickfive.gitit") + ".Extension"

    /// Re-reads both halves of `isDashboardReady`. Runs after each check and whenever
    /// GitIt comes forward (the user may have just turned the extension on or off).
    func refreshDashboardReadiness() async {
        guard dashboardURL != nil else {
            isDashboardReady = false
            return
        }
        let enabled = (try? await SFSafariExtensionManager.stateOfSafariExtension(withIdentifier: extensionId))?.isEnabled ?? false
        isDashboardReady = enabled
    }

    /// Opens the dashboard in Safari, when it is ready.
    ///
    /// Safari will not open an extension's page for another app, so the extension opens
    /// it: this leaves a request in the app group and brings Safari forward. Safari's
    /// window gaining focus wakes the extension, which asks for the status, finds the
    /// request in the answer, and opens the dashboard tab itself.
    func openDashboard() {
        guard isDashboardReady,
              let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { return }
        shared?.set(Date().timeIntervalSince1970, forKey: "dashboardRequestedAt")
        // Take focus first, so Safari's window gains it even if Safari was already in front
        // (the menu bar item does not activate GitIt on its own).
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: safari, configuration: configuration)
        }
    }

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.refreshRequest, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        activation = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshDashboardReadiness() }
        }
        restartLoop()
    }

    /// Call after the interval changes or the token is saved.
    func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                let minutes = self.settings.checkIntervalMinutes
                try? await Task.sleep(for: .seconds(minutes * 60))
            }
        }
    }

    func tokenChanged() {
        hasToken = Keychain.token?.isEmpty == false
        if !hasToken {
            summary = nil
            login = nil
            publish(nil)
            defaults.removeObject(forKey: seenKey)
            defaults.removeObject(forKey: seenPrimedKey)
            defaults.removeObject(forKey: lastCheckKey)
        }
        restartLoop()
    }

    func refresh() async {
        guard !isChecking else { return }
        guard let token = Keychain.token, !token.isEmpty else {
            hasToken = false
            return
        }
        hasToken = true
        isChecking = true
        defer { isChecking = false }

        let result = await client.fetch(token: token)
        if let name = result.login { login = name }
        let summary = AttentionSummary(
            checkedAt: Date(),
            login: login,
            items: result.items,
            errors: result.errors,
            checkIntervalMinutes: settings.checkIntervalMinutes,
            popupItemCount: settings.popupItemCount
        )
        self.summary = summary
        publish(summary)
        notifyAboutNew(in: summary.items, checkedAt: summary.checkedAt)
        await refreshDashboardReadiness()
    }

    /// Re-publishes the last result with the current settings, without another check.
    func settingsChanged() {
        guard var summary else { return }
        summary.checkIntervalMinutes = settings.checkIntervalMinutes
        summary.popupItemCount = settings.popupItemCount
        self.summary = summary
        publish(summary)
    }

    // MARK: Private

    private func publish(_ summary: AttentionSummary?) {
        guard let shared else { return }
        if let summary, let data = try? AttentionSummary.encoder.encode(summary) {
            shared.set(String(decoding: data, as: UTF8.self), forKey: "summary")
        } else {
            shared.removeObject(forKey: "summary")
        }
        shared.set(hasToken, forKey: "hasToken")
    }

    /// Notifies once per item, the first time it is seen with recent activity. The very
    /// first check after a token is saved only primes the list, so an existing backlog
    /// does not fire a storm.
    private func notifyAboutNew(in items: [AttentionItem], checkedAt: Date) {
        let current = Set(items.map(\.id))
        let primed = defaults.bool(forKey: seenPrimedKey)
        let seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        let previousCheck = defaults.object(forKey: lastCheckKey) as? Date
        defaults.set(Array(current), forKey: seenKey)
        defaults.set(true, forKey: seenPrimedKey)
        defaults.set(checkedAt, forKey: lastCheckKey)
        guard primed else { return }

        // An item is news only if something happened to it since the last check. An old
        // item that merely reappears (a request that failed last time, a list that
        // shifted) is not. The slack covers clock skew and GitHub's search index lag.
        // No saved time (first run after upgrading): assume the last check was one interval ago.
        let since = previousCheck ?? checkedAt.addingTimeInterval(-Double(settings.checkIntervalMinutes) * 60)
        let cutoff = since.addingTimeInterval(-10 * 60)
        let new = items.filter { !seen.contains($0.id) && $0.updatedAt > cutoff }
        guard !new.isEmpty else { return }
        guard settings.showSystemNotifications, !settings.muteNotifications else { return }
        notifier.notify(new: new)
    }
}
