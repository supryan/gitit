import AppKit
import UserNotifications

/// Posts real macOS notifications (Notification Center) and opens the item when one is clicked.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()
    private(set) var authorized = false

    /// When a notification was last clicked. The app delegate uses it to tell a click,
    /// which also reopens the app, from the user opening GitIt to see its window.
    private var lastClickAt: Date?
    var respondedRecently: Bool {
        lastClickAt.map { Date().timeIntervalSince($0) < 2 } ?? false
    }

    func prepare() {
        center.delegate = self
        center.getNotificationSettings { [weak self] settings in
            self?.authorized = settings.authorizationStatus == .authorized
        }
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    /// One notification per item up to three; past that, a single summary so a busy
    /// morning does not become a wall of banners.
    func notify(new items: [AttentionItem]) {
        guard !items.isEmpty else { return }
        if items.count <= 3 {
            for item in items {
                let content = UNMutableNotificationContent()
                content.title = item.reason ?? "Needs your attention"
                content.subtitle = item.number.map { "\(item.repository) #\($0)" } ?? item.repository
                content.body = item.title
                content.sound = .default
                content.userInfo = ["url": item.url]
                content.threadIdentifier = item.repository
                post(content, id: item.id)
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = "\(items.count) new items need your attention"
            content.body = items.prefix(4).map { "\($0.repository): \($0.title)" }.joined(separator: "\n")
            content.sound = .default
            content.userInfo = ["url": "gitit://dashboard"]
            post(content, id: "summary-\(Date().timeIntervalSince1970)")
        }
    }

    private func post(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        DispatchQueue.main.async { self.lastClickAt = Date() }
        guard let raw = response.notification.request.content.userInfo["url"] as? String else { return }
        if raw == "gitit://dashboard" {
            NSWorkspace.shared.open(Links.pullRequests)
        } else if let url = URL(string: raw) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// GitHub's own views of the same things, for the menu and the notifications.
enum Links {
    static let pullRequests = URL(string: "https://github.com/pulls?q=is%3Apr+is%3Aopen+involves%3A%40me+sort%3Aupdated-desc")!
    static let issues = URL(string: "https://github.com/issues?q=is%3Aissue+is%3Aopen+involves%3A%40me+sort%3Aupdated-desc")!
    static let reviewRequests = URL(string: "https://github.com/pulls/review-requested")!
    static let notifications = URL(string: "https://github.com/notifications?query=is%3Aunread")!
    static let newToken = URL(string: "https://github.com/settings/tokens/new?scopes=repo,notifications,read:org&description=GitIt")!
}
