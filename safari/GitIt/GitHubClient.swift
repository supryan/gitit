import Foundation

struct GitHubFetchResult {
    var login: String?
    var items: [AttentionItem]
    var errors: [String]
}

enum GitHubError: LocalizedError {
    case http(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .http(401, _): return "GitHub rejected the token (401)."
        case .http(403, let path) where path.hasPrefix("/notifications"):
            return "Notifications are unavailable: the token needs the notifications scope (403)."
        case .http(let code, let path): return "GitHub answered \(code) for \(path)."
        case .transport(let message): return message
        }
    }
}

/// Talks to the GitHub REST API. Every call is read-only.
actor GitHubClient {
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: Public

    /// Validates a token and returns the login it belongs to.
    func login(token: String) async throws -> String {
        let user: User = try await get("/user", token: token)
        return user.login
    }

    /// Gathers everything that needs the user's attention. Partial failures are returned
    /// in `errors`; the items found by the calls that succeeded still count.
    func fetch(token: String) async -> GitHubFetchResult {
        async let user = attempt { try await self.login(token: token) }
        async let reviews = attempt {
            try await self.search("is:pr is:open archived:false review-requested:@me", token: token)
        }
        async let assigned = attempt {
            try await self.search("is:open archived:false assignee:@me", token: token)
        }
        async let authored = attempt {
            try await self.search("is:pr is:open archived:false author:@me", token: token)
        }
        async let notifications = attempt { try await self.notifications(token: token) }

        let results = await (user, reviews, assigned, authored, notifications)
        var errors: [String] = []
        var merged: [String: AttentionItem] = [:]
        var order: [String] = []

        func add(_ item: AttentionItem) {
            if merged[item.url] == nil { order.append(item.url) }
            merged[item.url] = item
        }

        switch results.1 {
        case .success(let items):
            for item in items {
                add(make(item, kind: .reviewRequest, reason: "Review requested"))
            }
        case .failure(let error): errors.append(error.localizedDescription)
        }

        switch results.2 {
        case .success(let items):
            for item in items where merged[item.htmlUrl] == nil {
                add(make(item, kind: .assigned, reason: "Assigned to you"))
            }
        case .failure(let error): errors.append(error.localizedDescription)
        }

        switch results.3 {
        case .success(let items):
            for item in items where merged[item.htmlUrl] == nil {
                add(make(item, kind: .pullRequest, reason: item.draft == true ? "Your draft" : "Your pull request"))
            }
        case .failure(let error): errors.append(error.localizedDescription)
        }

        switch results.4 {
        case .success(let threads):
            for thread in threads where thread.reason != "ci_activity" {
                let url = thread.htmlUrl
                let reason = Self.reasonText[thread.reason] ?? thread.reason.replacingOccurrences(of: "_", with: " ").capitalized
                if var existing = merged[url] {
                    existing.hasUnread = true
                    existing.reason = reason
                    if thread.updatedAt > existing.updatedAt { existing.updatedAt = thread.updatedAt }
                    merged[url] = existing
                } else {
                    add(AttentionItem(
                        id: "notification:\(thread.id)",
                        kind: .notification,
                        subject: thread.subjectKind,
                        title: thread.subject.title,
                        repository: thread.repository.fullName,
                        number: thread.number,
                        url: url,
                        updatedAt: thread.updatedAt,
                        isDraft: false,
                        reason: reason,
                        hasUnread: true
                    ))
                }
            }
        case .failure(let error): errors.append(error.localizedDescription)
        }

        let login: String?
        switch results.0 {
        case .success(let name): login = name
        case .failure(let error):
            login = nil
            errors.insert(error.localizedDescription, at: 0)
        }

        let items = order.compactMap { merged[$0] }.sorted { $0.updatedAt > $1.updatedAt }
        return GitHubFetchResult(login: login, items: items, errors: Array(NSOrderedSet(array: errors)) as? [String] ?? errors)
    }

    // MARK: Requests

    private func attempt<T>(_ work: @escaping () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func search(_ query: String, token: String) async throws -> [SearchItem] {
        let response: SearchResponse = try await get("/search/issues", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "advanced_search", value: "true"),
        ], token: token)
        return response.items
    }

    private func notifications(token: String) async throws -> [NotificationThread] {
        try await get("/notifications", query: [
            URLQueryItem(name: "per_page", value: "100"),
        ], token: token)
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], token: String) async throws -> T {
        var components = URLComponents(string: "https://api.github.com")!
        components.path = path
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GitIt", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubError.transport("Could not reach GitHub: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw GitHubError.http(status, path) }
        return try decoder.decode(T.self, from: data)
    }

    private func make(_ item: SearchItem, kind: AttentionItem.Kind, reason: String) -> AttentionItem {
        let prefix = item.pullRequest == nil ? "issue" : "pull"
        return AttentionItem(
            id: "\(prefix):\(item.repositoryName)#\(item.number)",
            kind: kind,
            subject: item.pullRequest == nil ? .issue : .pullRequest,
            title: item.title,
            repository: item.repositoryName,
            number: item.number,
            url: item.htmlUrl,
            updatedAt: item.updatedAt,
            isDraft: item.draft ?? false,
            reason: reason,
            hasUnread: false
        )
    }

    private static let reasonText: [String: String] = [
        "mention": "Mentioned you",
        "team_mention": "Mentioned your team",
        "comment": "New comment",
        "review_requested": "Review requested",
        "assign": "Assigned to you",
        "author": "Activity on your thread",
        "state_change": "State changed",
        "subscribed": "New activity",
        "manual": "New activity",
        "approval_requested": "Approval requested",
        "invitation": "Invitation",
        "security_alert": "Security alert",
        "member_feature_requested": "Feature requested",
    ]
}

// MARK: - Wire types

private struct User: Decodable {
    let login: String
}

private struct SearchResponse: Decodable {
    let items: [SearchItem]
}

private struct SearchItem: Decodable {
    struct PullRequestRef: Decodable {
        let url: String?
    }

    let number: Int
    let title: String
    let htmlUrl: String
    let updatedAt: Date
    let draft: Bool?
    let repositoryUrl: String
    let pullRequest: PullRequestRef?

    /// "owner/repo" from "https://api.github.com/repos/owner/repo".
    var repositoryName: String {
        repositoryUrl.split(separator: "/").suffix(2).joined(separator: "/")
    }
}

private struct NotificationThread: Decodable {
    struct Subject: Decodable {
        let title: String
        let url: String?
        let type: String
    }

    struct Repository: Decodable {
        let fullName: String
        let htmlUrl: String
    }

    let id: String
    let reason: String
    let updatedAt: Date
    let subject: Subject
    let repository: Repository

    /// The page to open: the API's subject URL turned into a github.com one. Threads
    /// without a subject URL (discussions, check suites) open the repository.
    var htmlUrl: String {
        guard let url = subject.url else { return repository.htmlUrl }
        return url
            .replacingOccurrences(of: "https://api.github.com/repos/", with: "https://github.com/")
            .replacingOccurrences(of: "/pulls/", with: "/pull/")
    }

    var number: Int? {
        guard let last = subject.url?.split(separator: "/").last else { return nil }
        return Int(last)
    }

    var subjectKind: AttentionItem.Subject {
        switch subject.type {
        case "PullRequest": return .pullRequest
        case "Issue": return .issue
        default: return .other
        }
    }
}
