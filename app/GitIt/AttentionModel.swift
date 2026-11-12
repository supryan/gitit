import Foundation

/// One thing on GitHub that is waiting on the user.
struct AttentionItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        /// An open pull request the user authored (drafts included).
        case pullRequest
        /// An open pull request whose review was requested from the user (or their team).
        case reviewRequest
        /// An open issue or pull request assigned to the user.
        case assigned
        /// An unread notification: a mention, a comment, a state change, an invitation…
        case notification
    }

    /// What the item is on GitHub, regardless of why it is here.
    enum Subject: String, Codable {
        case issue, pullRequest, other
    }

    var id: String
    var kind: Kind
    var subject: Subject
    var title: String
    var repository: String
    var number: Int?
    var url: String
    var updatedAt: Date
    var isDraft: Bool
    /// Why it needs attention, for the dashboard ("Mentioned you", "Review requested").
    var reason: String?
    /// True when an unread notification exists for the thread.
    var hasUnread: Bool
}

/// Everything the app found on its last check. Written to the app group as JSON for the
/// Safari extension, which reads it as-is; keep the keys stable (see dashboard.js).
struct AttentionSummary: Codable {
    var checkedAt: Date
    var login: String?
    var items: [AttentionItem]
    var errors: [String]
    var checkIntervalMinutes: Int
    /// How many items the Safari popup lists per tab (the app's "Popup shows" setting).
    var popupItemCount: Int

    var total: Int { items.count }

    func items(of kind: AttentionItem.Kind) -> [AttentionItem] {
        items.filter { $0.kind == kind }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
