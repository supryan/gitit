import AppKit
import SwiftUI

/// The menu under the menu bar item: the items themselves, then the app's own commands.
struct MenuBarView: View {
    @State private var monitor = Monitor.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !monitor.hasToken {
            Text("Add a personal access token in Settings.")
        } else if let summary = monitor.summary {
            if summary.items.isEmpty {
                Text("You're all caught up.")
            } else {
                ForEach(summary.items.prefix(15)) { item in
                    Button {
                        if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
                    } label: {
                        Text(menuLine(for: item))
                    }
                }
                if summary.items.count > 15 {
                    Text("…and \(summary.items.count - 15) more")
                }
            }
            Divider()
            Text(lastChecked(summary.checkedAt))
        } else {
            Text(monitor.isChecking ? "Checking…" : "Not checked yet.")
        }

        Divider()

        Button("Check Now") { Task { await monitor.refresh() } }
            .disabled(!monitor.hasToken || monitor.isChecking)
            .keyboardShortcut("r")
        Button("Pull Requests on GitHub") { NSWorkspace.shared.open(Links.pullRequests) }
        Button("Issues on GitHub") { NSWorkspace.shared.open(Links.issues) }
        Button("Notifications on GitHub") { NSWorkspace.shared.open(Links.notifications) }

        Divider()

        Button("Settings…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Button("Quit GitIt") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func menuLine(for item: AttentionItem) -> String {
        let number = item.number.map { " #\($0)" } ?? ""
        let flag = item.hasUnread ? "● " : ""
        return "\(flag)\(item.repository)\(number): \(item.title)"
    }

    private func lastChecked(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Checked \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

/// The menu bar item itself: a tray glyph with the count beside it.
struct MenuBarLabel: View {
    @State private var monitor = Monitor.shared

    var body: some View {
        if monitor.hasToken, monitor.total > 0 {
            Label("\(monitor.total)", systemImage: "tray.full")
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: "tray")
        }
    }
}
