import AppKit
import Observation

/// GitIt's menu bar item: a tray glyph with the count beside it, and a menu of the items.
///
/// A plain NSStatusItem rather than SwiftUI's MenuBarExtra. Menu bar managers such as
/// Dimble could not find the SwiftUI item to show or hide it; this one is created once,
/// never rebuilt, and has a fixed autosave name, so macOS and those tools can track it.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()

    private let monitor = Monitor.shared
    private let settings = AppSettings.shared
    private var item: NSStatusItem?
    private var hosting: PassthroughHostingView<MenuBarIconView>?

    func start() {
        update()
        observe()
    }

    /// Re-runs `update` whenever anything it reads changes.
    private func observe() {
        withObservationTracking {
            _ = settings.showMenuBarIcon
            _ = settings.menuBarIconStyle
            _ = monitor.hasToken
            _ = monitor.total
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.update()
                self?.observe()
            }
        }
    }

    private func update() {
        guard settings.showMenuBarIcon else {
            remove()
            return
        }
        let item = self.item ?? makeItem()
        let count = monitor.hasToken ? monitor.total : 0
        guard let button = item.button else { return }
        let content = MenuBarIconView(style: settings.menuBarIconStyle, count: count)
        let hosting = self.hosting ?? makeHosting(in: button)
        hosting.rootView = content
        hosting.layoutSubtreeIfNeeded()
        // The item must be as wide as the content: macOS 14+ does not clip subviews, so a
        // too-narrow item shows the tray and hides the number under the next item.
        item.length = ceil(hosting.intrinsicContentSize.width) + 12
        hosting.frame = button.bounds
        button.setAccessibilityLabel(count > 0 ? "GitIt, \(count) waiting on you" : "GitIt")
    }

    private func makeHosting(in button: NSStatusBarButton) -> PassthroughHostingView<MenuBarIconView> {
        let hosting = PassthroughHostingView(rootView: MenuBarIconView(style: .plain, count: 0))
        hosting.sizingOptions = .intrinsicContentSize
        hosting.autoresizingMask = [.width, .height]
        button.addSubview(hosting)
        self.hosting = hosting
        return hosting
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "GitIt"
        // Not removable by ⌘-drag: macOS drops user-removable items first when the bar is
        // crowded, and Dimble hides icons by crowding it. The setting hides the icon instead.
        item.behavior = []
        item.isVisible = true // the setting decides, not a visibility AppKit saved earlier
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = 380 // room for a subtitle on one line
        menu.delegate = self
        item.menu = menu
        self.item = item
        return item
    }

    private func remove() {
        guard let item else { return }
        NSStatusBar.system.removeStatusItem(item)
        self.item = nil
        hosting = nil
    }

    // MARK: The menu

    /// How many items the menu lists before "…and N more".
    private static let itemLimit = 15
    private static let titleLimit = 60

    /// The groups, most urgent first.
    private static let sections: [(kind: AttentionItem.Kind, title: String)] = [
        (.reviewRequest, "Review requested"),
        (.assigned, "Assigned to you"),
        (.pullRequest, "Your pull requests"),
        (.notification, "Unread activity"),
    ]

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !monitor.hasToken {
            menu.addItem(note("Add a personal access token in Settings.", symbol: "key"))
        } else if let summary = monitor.summary {
            if summary.items.isEmpty {
                menu.addItem(note("You're all caught up.", symbol: "checkmark.circle"))
            } else {
                addItems(of: summary, to: menu)
            }
        }

        // When it last checked, then the two things to do about it; same icons as the
        // Check and Dashboard buttons in Settings.
        menu.addItem(.separator())
        if let summary = monitor.summary, monitor.hasToken {
            menu.addItem(note(monitor.isChecking ? "Checking…" : lastChecked(summary.checkedAt), symbol: "clock"))
        } else if monitor.hasToken {
            menu.addItem(note(monitor.isChecking ? "Checking…" : "Not checked yet.", symbol: "clock"))
        }
        let check = action("Check Now", symbol: "arrow.clockwise", key: "r") { Task { await Monitor.shared.refresh() } }
        check.isEnabled = monitor.hasToken && !monitor.isChecking
        menu.addItem(check)
        let dashboard = action("Dashboard", symbol: "list.bullet.rectangle", key: "d") { Monitor.shared.openDashboard() }
        dashboard.isEnabled = monitor.isDashboardReady
        if !monitor.isDashboardReady {
            dashboard.toolTip = "Available once the Safari extension is on and has run."
        }
        menu.addItem(dashboard)
        // The extension may have been turned on or off since; this menu shows the last
        // known state, and the next one the fresh one.
        Task { await monitor.refreshDashboardReadiness() }

        menu.addItem(.separator())
        menu.addItem(action("Pull Requests on GitHub", symbol: "arrow.triangle.pull") { NSWorkspace.shared.open(Links.pullRequests) })
        menu.addItem(action("Issues on GitHub", symbol: "smallcircle.filled.circle") { NSWorkspace.shared.open(Links.issues) })
        menu.addItem(action("Notifications on GitHub", symbol: "bell") { NSWorkspace.shared.open(Links.notifications) })

        menu.addItem(.separator())
        menu.addItem(action("Settings…", symbol: "gearshape", key: ",") { SettingsWindow.shared.show() })
        menu.addItem(action("Quit GitIt", symbol: "power", key: "q") { NSApp.terminate(nil) })
    }

    /// The items grouped under a section header per kind, capped at `itemLimit` in all.
    private func addItems(of summary: AttentionSummary, to menu: NSMenu) {
        var remaining = Self.itemLimit
        var first = true
        for section in Self.sections where remaining > 0 {
            let entries = summary.items(of: section.kind)
            guard !entries.isEmpty else { continue }
            if !first { menu.addItem(.separator()) }
            first = false
            let header = NSMenuItem.sectionHeader(title: section.title)
            header.badge = NSMenuItemBadge(count: entries.count)
            menu.addItem(header)
            for entry in entries.prefix(remaining) {
                menu.addItem(row(for: entry, in: section.kind))
            }
            remaining -= min(entries.count, remaining)
        }
        let hidden = summary.items.count - Self.itemLimit
        if hidden > 0 {
            menu.addItem(note("…and \(hidden) more", symbol: "ellipsis"))
        }
    }

    private func row(for entry: AttentionItem, in kind: AttentionItem.Kind) -> NSMenuItem {
        let item = action(Self.truncated(entry.title)) {
            if let url = URL(string: entry.url) { NSWorkspace.shared.open(url) }
        }
        item.image = Self.dot(for: entry.kind)
        item.showImage()
        let subtitle = Self.subtitle(for: entry, in: kind)
        if #available(macOS 14.4, *) {
            item.subtitle = subtitle
        }
        if entry.isDraft {
            item.badge = NSMenuItemBadge(string: "Draft")
        }
        item.toolTip = entry.title + "\n" + subtitle
        return item
    }

    /// "owner/repo #123", plus the reason when it says more than the section header does:
    /// unread activity on an item carries the notification's reason ("New comment").
    private static func subtitle(for entry: AttentionItem, in kind: AttentionItem.Kind) -> String {
        var parts = [entry.number.map { "\(entry.repository) #\($0)" } ?? entry.repository]
        if kind == .notification || entry.hasUnread, let reason = entry.reason, !reason.isEmpty {
            parts.append(reason)
        }
        return parts.joined(separator: " · ")
    }

    /// The status dots from the popup: one colour per kind.
    private static var dots: [AttentionItem.Kind: NSImage] = [:]

    private static func dot(for kind: AttentionItem.Kind) -> NSImage {
        if let image = dots[kind] { return image }
        let color = kind.nsColor
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        dots[kind] = image
        return image
    }

    private static func truncated(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > titleLimit else { return trimmed }
        return trimmed.prefix(titleLimit - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    private func note(_ title: String, symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = symbol.flatMap(Self.image)
        item.showImage()
        return item
    }

    private func action(_ title: String, symbol: String? = nil, key: String = "", run: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, key: key, run: run)
        item.image = symbol.flatMap(Self.image)
        item.showImage()
        return item
    }

    private static let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)

    private static func image(_ symbol: String) -> NSImage? {
        NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
    }

    private func lastChecked(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Checked \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private extension NSMenuItem {
    /// macOS 27 leaves menu item images out unless the item asks for them.
    func showImage() {
        if #available(macOS 27, *) {
            preferredImageVisibility = .visible
        }
    }
}

/// A menu item that runs a closure.
private final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, key: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}
