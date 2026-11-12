import Foundation
import SafariServices
import os.log

/// Answers the web extension's native messages. It never talks to GitHub itself: the app
/// polls and leaves its latest summary in the app group, and this hands it over.
///
/// Messages:
///   { type: "status" }  -> { available, hasToken, summary }
///   { type: "refresh" } -> asks the app (if running) to check now, then answers as "status"
///
/// Both may carry `dashboard`, the dashboard page's URL. Safari picks the extension's URL
/// at install, so the app cannot know it; it is kept in the app group for Settings' button.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private static let appGroup = Bundle.main.object(forInfoDictionaryKey: "GitItAppGroup") as? String
    private static let refreshRequest = Notification.Name("com.jickfive.gitit.refresh")

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        let type = message?["type"] as? String ?? "status"

        if let dashboard = message?["dashboard"] as? String {
            rememberDashboard(dashboard)
        }

        if type == "refresh" {
            DistributedNotificationCenter.default().postNotificationName(
                Self.refreshRequest, object: nil, userInfo: nil, deliverImmediately: true
            )
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: status()]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func rememberDashboard(_ url: String) {
        guard let group = Self.appGroup, let shared = UserDefaults(suiteName: group),
              shared.string(forKey: "dashboardURL") != url else { return }
        shared.set(url, forKey: "dashboardURL")
    }

    private func status() -> [String: Any] {
        guard let group = Self.appGroup, let shared = UserDefaults(suiteName: group) else {
            return ["available": false, "hasToken": false, "error": "appGroupUnavailable"]
        }
        var payload: [String: Any] = [
            "available": true,
            "hasToken": shared.bool(forKey: "hasToken"),
        ]
        if let json = shared.string(forKey: "summary"),
           let data = json.data(using: .utf8),
           let summary = try? JSONSerialization.jsonObject(with: data) {
            payload["summary"] = summary
        } else {
            payload["summary"] = NSNull()
        }
        return payload
    }
}
