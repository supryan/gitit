import Foundation

/// GitIt's native messaging host for the Chrome extension.
///
/// Chrome starts GitIt's own executable with the extension's origin as its argument
/// (`chrome-extension://<id>/`) and talks to it over stdin and stdout: each message is a
/// 4-byte length, then that many bytes of JSON. GitIt answers like the Safari extension's
/// handler does, from the result the running app leaves in the app group, so the Chrome
/// extension never holds the token or talks to GitHub either.
///
/// Messages:
///   { type: "status" }  -> { available, hasToken, summary }
///   { type: "refresh" } -> asks the running app to check now, then answers as "status"
///
/// Each message also tells the app the extension is loaded (`chromeLastSeen`, which
/// Settings' Chrome row reads), and the answer carries `openDashboard: true` once after
/// the app's Dashboard button chose Chrome.
///
/// Chrome finds this host through a manifest in its NativeMessagingHosts folder, written by
/// `make chrome` (chrome/build.sh), which names this executable and the extension's id.
@MainActor
enum ChromeNativeHost {
    /// Whether Chrome launched GitIt as its native messaging host.
    static var isRequested: Bool {
        CommandLine.arguments.dropFirst().contains { $0.hasPrefix("chrome-extension://") }
    }

    private static let refreshRequest = Notification.Name("com.gitit.app.refresh")

    /// Answers messages until Chrome closes stdin, then returns.
    static func run() {
        let input = FileHandle.standardInput
        let output = FileHandle.standardOutput
        while let message = readMessage(from: input) {
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "chromeLastSeen")
            if message["type"] as? String == "refresh" {
                DistributedNotificationCenter.default().postNotificationName(
                    refreshRequest, object: nil, userInfo: nil, deliverImmediately: true
                )
            }
            write(status(), to: output)
        }
    }

    private static func readMessage(from input: FileHandle) -> [String: Any]? {
        let header = input.readData(ofLength: 4)
        guard header.count == 4 else { return nil }
        let length = header.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
        guard length > 0, length < 1_048_576 else { return nil }
        let body = input.readData(ofLength: Int(length))
        guard body.count == Int(length) else { return nil }
        return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    private static func write(_ object: [String: Any], to output: FileHandle) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        var length = UInt32(data.count).littleEndian
        output.write(Data(bytes: &length, count: 4))
        output.write(data)
    }

    private static var sharedDefaults: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "GitItAppGroup") as? String).flatMap(UserDefaults.init(suiteName:))
    }

    private static func status() -> [String: Any] {
        guard let shared = sharedDefaults else {
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
        // A Dashboard request from the app aimed at Chrome: hand it over once, if recent.
        if let requested = shared.object(forKey: "chromeDashboardRequestedAt") as? Double {
            shared.removeObject(forKey: "chromeDashboardRequestedAt")
            if Date().timeIntervalSince1970 - requested < 90 { payload["openDashboard"] = true }
        }
        return payload
    }
}
