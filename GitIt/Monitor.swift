import AppKit
import Foundation
import Observation

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

    private let defaults = UserDefaults.standard
    private let seenKey = "seenItemIds"
    private let seenPrimedKey = "seenItemsPrimed"

    /// The suite shared with the extension; nil when the entitlement did not take.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "GitItAppGroup") as? String
    @ObservationIgnored private let shared: UserDefaults? = Monitor.appGroup.flatMap { UserDefaults(suiteName: $0) }

    var total: Int { summary?.total ?? 0 }

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.refreshRequest, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
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
        notifyAboutNew(in: summary.items)
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

    /// Notifies once per item, the first time it is seen. The very first check after a
    /// token is saved only primes the list, so an existing backlog does not fire a storm.
    private func notifyAboutNew(in items: [AttentionItem]) {
        let current = Set(items.map(\.id))
        let primed = defaults.bool(forKey: seenPrimedKey)
        let seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        defaults.set(Array(current), forKey: seenKey)
        defaults.set(true, forKey: seenPrimedKey)
        guard primed else { return }

        let new = items.filter { !seen.contains($0.id) }
        guard !new.isEmpty else { return }
        guard settings.showSystemNotifications, !settings.muteNotifications else { return }
        notifier.notify(new: new)
    }
}
