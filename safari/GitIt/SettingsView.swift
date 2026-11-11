import SafariServices
import SwiftUI

/// The app's one window: General, Safari Extension, GitHub, and what the last check found.
struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var monitor = Monitor.shared

    @State private var tokenDraft = ""
    @State private var tokenStatus: TokenStatus = .none
    @State private var isSavingToken = false
    @State private var extensionState: ExtensionState = .unknown

    private let extensionId = (Bundle.main.bundleIdentifier ?? "com.jickfive.gitit") + ".Extension"

    enum TokenStatus: Equatable {
        case none
        case saved(login: String)
        case error(String)
    }

    enum ExtensionState {
        case unknown, enabled, disabled, error(String)

        var label: String {
            switch self {
            case .unknown: return "Checking…"
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .error: return "Not installed"
            }
        }
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Mute notifications", isOn: $settings.muteNotifications)
                Toggle("Show system notifications", isOn: $settings.showSystemNotifications)
                    .onChange(of: settings.showSystemNotifications) { _, on in
                        if on { Notifier.shared.requestAuthorization() }
                    }
                Picker("Check every", selection: $settings.checkIntervalMinutes) {
                    ForEach(AppSettings.intervalChoices, id: \.self) { minutes in
                        Text(AppSettings.label(forMinutes: minutes)).tag(minutes)
                    }
                }
                .onChange(of: settings.checkIntervalMinutes) { _, _ in
                    monitor.settingsChanged()
                    monitor.restartLoop()
                }
                Picker("Popup shows", selection: $settings.popupItemCount) {
                    ForEach(AppSettings.popupCountChoices, id: \.self) { count in
                        Text("\(count) items per tab").tag(count)
                    }
                }
                .onChange(of: settings.popupItemCount) { _, _ in monitor.settingsChanged() }
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                if let error = settings.launchAtLoginError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Status") {
                    Text(extensionState.label).foregroundStyle(.secondary)
                }
                Button("Open Safari Extension Settings…") {
                    SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionId)
                }
                if case .error(let message) = extensionState {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            } header: {
                Text("Safari Extension")
            } footer: {
                Text("Optional. Shows the count as a badge on a Safari toolbar button; clicking it opens the GitIt dashboard.")
            }

            Section {
                SecureField("Personal Access Token", text: $tokenDraft)
                    .textContentType(.password)
                    .onSubmit(saveToken)
                HStack {
                    tokenStatusView
                    Spacer()
                    if monitor.hasToken {
                        Button("Remove", role: .destructive) { removeToken() }
                    }
                    Button("Save", action: saveToken)
                        .disabled(tokenDraft.trimmingCharacters(in: .whitespaces).isEmpty || isSavingToken)
                        .keyboardShortcut(.defaultAction)
                }
            } header: {
                Text("GitHub")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requires a classic personal access token with the notifications scope (plus repo and read:org to see private repositories and organizations).")
                    Link("Create one on GitHub…", destination: Links.newToken)
                }
            }

            Section {
                statusRows
            } header: {
                Text("Status")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 620)
        .task { await refreshExtensionState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLaunchAtLogin()
            Task { await refreshExtensionState() }
        }
        .onAppear {
            if let login = monitor.login, monitor.hasToken { tokenStatus = .saved(login: login) }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var tokenStatusView: some View {
        switch tokenStatus {
        case .none:
            if monitor.hasToken, let login = monitor.login {
                Text("Signed in as @\(login).").foregroundStyle(.secondary)
            } else if monitor.hasToken {
                Text("Token saved.").foregroundStyle(.secondary)
            } else {
                Text("Add a personal access token to start.").foregroundStyle(.secondary)
            }
        case .saved(let login):
            Text("Signed in as @\(login).").foregroundStyle(.secondary)
        case .error(let message):
            Text(message).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statusRows: some View {
        LabeledContent("Needs your attention") {
            Text(monitor.hasToken ? "\(monitor.total)" : "—").foregroundStyle(.secondary)
        }
        LabeledContent("Last checked") {
            if let at = monitor.summary?.checkedAt {
                Text(at, style: .relative).foregroundStyle(.secondary) + Text(" ago").foregroundStyle(.secondary)
            } else {
                Text("Never").foregroundStyle(.secondary)
            }
        }
        if let summary = monitor.summary {
            LabeledContent("Review requests") { Text("\(summary.items(of: .reviewRequest).count)").foregroundStyle(.secondary) }
            LabeledContent("Assigned") { Text("\(summary.items(of: .assigned).count)").foregroundStyle(.secondary) }
            LabeledContent("Your pull requests") { Text("\(summary.items(of: .pullRequest).count)").foregroundStyle(.secondary) }
            LabeledContent("Unread activity") { Text("\(summary.items(of: .notification).count)").foregroundStyle(.secondary) }
            ForEach(summary.errors, id: \.self) { error in
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        HStack {
            Button(monitor.isChecking ? "Checking…" : "Check now") {
                Task { await monitor.refresh() }
            }
            .disabled(!monitor.hasToken || monitor.isChecking)
            Spacer()
            Link("Pull requests", destination: Links.pullRequests)
            Link("Issues", destination: Links.issues)
            Link("Notifications", destination: Links.notifications)
        }
    }

    // MARK: Actions

    private func saveToken() {
        let token = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !isSavingToken else { return }
        isSavingToken = true
        Task {
            defer { isSavingToken = false }
            do {
                let login = try await GitHubClient().login(token: token)
                try Keychain.save(token)
                tokenDraft = ""
                tokenStatus = .saved(login: login)
                monitor.tokenChanged()
                if settings.showSystemNotifications { Notifier.shared.requestAuthorization() }
            } catch {
                tokenStatus = .error(error.localizedDescription)
            }
        }
    }

    private func removeToken() {
        Keychain.delete()
        tokenDraft = ""
        tokenStatus = .none
        monitor.tokenChanged()
    }

    private func refreshExtensionState() async {
        do {
            let state = try await SFSafariExtensionManager.stateOfSafariExtension(withIdentifier: extensionId)
            extensionState = state.isEnabled ? .enabled : .disabled
        } catch {
            extensionState = .error("Safari has not seen the extension yet. Keep GitIt in ~/Applications and open it once; then enable it in Safari > Settings > Extensions.")
        }
    }
}

#Preview {
    SettingsView()
}
