import SafariServices
import SwiftUI

/// The app's one window: a header with the account and the counts, then GitHub,
/// Notifications, and the app's own options.
struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var monitor = Monitor.shared

    @State private var tokenDraft = ""
    @State private var tokenStatus: TokenStatus = .none
    @State private var isSavingToken = false
    @State private var isEditingToken = false
    @State private var extensionState: ExtensionState = .unknown

    private let extensionId = (Bundle.main.bundleIdentifier ?? "com.jickfive.gitit") + ".Extension"

    enum TokenStatus: Equatable {
        case none
        case saved(login: String)
        case error(String)
    }

    enum ExtensionState {
        case unknown, enabled, disabled, error(String)

        var isEnabled: Bool {
            if case .enabled = self { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 8)

            Form {
                gitHubSection
                generalSection
                notificationsSection
                browsersSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(WindowBackground().ignoresSafeArea())
        .frame(width: 560, height: 740)
        .task { await refreshExtensionState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLaunchAtLogin()
            Task { await refreshExtensionState() }
        }
        .onAppear {
            if let login = monitor.login, monitor.hasToken { tokenStatus = .saved(login: login) }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // From the bundle itself, not the system icon cache, which can lag a reinstall.
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GitIt")
                        .font(.title2.weight(.semibold))
                    headline
                        .font(.callout)
                        .foregroundStyle(Color.headerSubtitle)
                    if let checkedAt = monitor.summary?.checkedAt {
                        (Text("Checked ") + Text(checkedAt, style: .relative) + Text(" ago"))
                            .font(.caption)
                            .foregroundStyle(Color.headerSubtitle)
                            .monospacedDigit()
                    }
                }
                .lineLimit(1)
                Spacer()
                HStack(spacing: 8) {
                    // "Check" stays put while checking; only its icon turns into a spinner.
                    Button {
                        Task { await monitor.refresh() }
                    } label: {
                        Label {
                            Text("Check")
                        } icon: {
                            if monitor.isChecking {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .prominentButton()
                    .disabled(!monitor.hasToken || monitor.isChecking)
                    .help("Check GitHub now")

                    Button {
                        monitor.openDashboard()
                    } label: {
                        Label("Dashboard", systemImage: "list.bullet.rectangle")
                    }
                    .glassButton()
                    .disabled(!monitor.isDashboardReady)
                    .help(monitor.isDashboardReady
                          ? "Open the dashboard in Safari"
                          : "Available once the Safari extension is on and has run.")
                }
            }

            let summary = monitor.summary
            HStack(spacing: 10) {
                tile(summary?.items(of: .reviewRequest).count, "Review requests", AttentionItem.Kind.reviewRequest.color, Links.reviewRequests)
                tile(summary?.items(of: .assigned).count, "Assigned", AttentionItem.Kind.assigned.color, Links.issues)
                tile(summary?.items(of: .pullRequest).count, "Your PRs", AttentionItem.Kind.pullRequest.color, Links.pullRequests)
                tile(summary?.items(of: .notification).count, "Unread", AttentionItem.Kind.notification.color, Links.notifications)
            }

            if let errors = summary?.errors, !errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors, id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle")
                    }
                }
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .card()
            }
        }
    }

    private var headline: Text {
        guard monitor.hasToken else { return Text("Add a GitHub token to get started.") }
        guard let summary = monitor.summary else {
            return Text(monitor.isChecking ? "Checking GitHub…" : "Not checked yet.")
        }
        let who = monitor.login.map { "@\($0) · " } ?? ""
        let need = summary.total == 1 ? "1 item needs you" : "\(summary.total) items need you"
        return Text(who + need)
    }

    private func tile(_ count: Int?, _ label: String, _ tint: Color, _ link: URL) -> some View {
        Button {
            NSWorkspace.shared.open(link)
        } label: {
            VStack(spacing: 2) {
                Text(count.map(String.init) ?? "–")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle((count ?? 0) > 0 ? tint : .secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card(interactive: true)
        .help("Open on GitHub")
    }

    // MARK: Sections

    private var gitHubSection: some View {
        Section {
            if monitor.hasToken, !isEditingToken {
                // No secure field while signed in: a focused one turns on secure keyboard
                // input, which blocks other apps' shortcuts for as long as the window is open.
                HStack(spacing: 12) {
                    Text("Token")
                    DotRow()
                        .accessibilityLabel("Saved token, hidden")
                }
            } else {
                SecureField("Token", text: $tokenDraft, prompt: Text("Paste a personal access token"))
                    .textContentType(.password)
                    .onSubmit(saveToken)
            }
            // The buttons keep their place; only their labels and actions change.
            HStack {
                tokenStatusView
                Spacer()
                if monitor.hasToken, !isEditingToken {
                    tokenButton("Change…") { isEditingToken = true }
                    tokenButton("Remove", role: .destructive) { removeToken() }
                } else {
                    if monitor.hasToken {
                        tokenButton("Cancel") {
                            isEditingToken = false
                            tokenDraft = ""
                        }
                    }
                    tokenButton("Save", action: saveToken)
                        .disabled(tokenDraft.trimmingCharacters(in: .whitespaces).isEmpty || isSavingToken)
                        .keyboardShortcut(.defaultAction)
                }
            }
        } header: {
            Text("GitHub")
        } footer: {
            Text("A classic personal access token with the notifications scope, plus repo and read:org for private repositories and organizations. [Create one on GitHub…](\(Links.newToken.absoluteString))")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Show system notifications", isOn: $settings.showSystemNotifications)
                .onChange(of: settings.showSystemNotifications) { _, on in
                    if on { Notifier.shared.requestAuthorization() }
                }
            Toggle("Mute notifications", isOn: $settings.muteNotifications)
            Picker("Check every", selection: $settings.checkIntervalMinutes) {
                ForEach(AppSettings.intervalChoices, id: \.self) { minutes in
                    Text(AppSettings.label(forMinutes: minutes)).tag(minutes)
                }
            }
            .onChange(of: settings.checkIntervalMinutes) { _, _ in
                monitor.settingsChanged()
                monitor.restartLoop()
            }
        }
    }

    private var generalSection: some View {
        Section {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            if let error = settings.launchAtLoginError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            if settings.showMenuBarIcon {
                MenuBarStylePicker(selection: $settings.menuBarIconStyle)
            }
        } header: {
            Text("General")
        } footer: {
            if !settings.showMenuBarIcon {
                HStack(alignment: .firstTextBaseline) {
                    Text("GitIt keeps running without a menu bar icon. Open it from Applications or Spotlight to get back here.")
                    Spacer()
                    Button("Quit GitIt") { NSApp.terminate(nil) }
                }
            }
        }
    }

    private var browsersSection: some View {
        Section {
            browserRow("Safari", icon: Browser.safariIcon, status: safariStatus) {
                Button(extensionState.isEnabled ? "Settings…" : "Enable…") {
                    SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionId)
                }
            }
            if case .error(let message) = extensionState {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            browserRow("Chrome", icon: Browser.chromeIcon, status: .init("Coming soon", symbol: "clock", tint: .gray)) {
                Button("Install") {}
                    .disabled(true)
            }
            Picker("Popup shows", selection: $settings.popupItemCount) {
                ForEach(AppSettings.popupCountChoices, id: \.self) { count in
                    Text("\(count) items per tab").tag(count)
                }
            }
            .onChange(of: settings.popupItemCount) { _, _ in monitor.settingsChanged() }
        } header: {
            Text("Browser Extensions")
        } footer: {
            Text("The extension shows the count on a toolbar button; its popup lists the most recent items. Chrome support is on the way.")
        }
    }

    private var safariStatus: Status {
        switch extensionState {
        case .unknown: return .init("Checking…", symbol: "ellipsis", tint: .gray)
        case .enabled: return .init("Enabled", symbol: "checkmark", tint: .green)
        case .disabled: return .init("Disabled", symbol: "xmark", tint: .orange)
        case .error: return .init("Not installed", symbol: "exclamationmark", tint: .gray)
        }
    }

    /// One browser: its icon and name, a status badge, and the button for what to do next.
    private func browserRow<Action: View>(_ name: String, icon: NSImage, status: Status, @ViewBuilder action: () -> Action) -> some View {
        LabeledContent {
            action()
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                    HStack(spacing: 3) {
                        Image(systemName: status.symbol)
                            .font(.caption2.weight(.bold))
                        Text(status.text)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(status.tint, in: Capsule())
                }
            }
        }
    }

    struct Status {
        let text: String
        let symbol: String
        let tint: Color
        init(_ text: String, symbol: String, tint: Color) {
            self.text = text; self.symbol = symbol; self.tint = tint
        }
    }

    /// Same width for every token button, so swapping them moves nothing.
    private func tokenButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title).frame(minWidth: 60)
        }
    }

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
                isEditingToken = false
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
        isEditingToken = false
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

// MARK: - Token dots

/// A row of dots standing in for the saved token, as many as fit. Drawn, not text: a
/// text of dots would give the form a huge ideal width and push every row off the window.
private struct DotRow: View {
    var body: some View {
        Canvas { context, size in
            let diameter: CGFloat = 3
            let pitch: CGFloat = 6.5
            var x: CGFloat = 0
            while x + diameter <= size.width {
                let rect = CGRect(x: x, y: (size.height - diameter) / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(.primary))
                x += pitch
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 12)
    }
}

// MARK: - Header colour

private extension Color {
    /// The header's account line and "Checked … ago": a grey that stays readable on the
    /// translucent window (5.9:1 light, 5.5:1 dark), where the system's secondary and
    /// tertiary greys wash out.
    static let headerSubtitle = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0xB4 / 255, green: 0xB4 / 255, blue: 0xB4 / 255, alpha: 1)
            : NSColor(srgbRed: 0x54 / 255, green: 0x54 / 255, blue: 0x54 / 255, alpha: 1)
    })
}

// MARK: - Browsers

private enum Browser {
    /// /Applications/Safari.app is a symlink into the system cryptex; resolved, or the
    /// icon carries an alias arrow.
    static let safariIcon = NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: "/Applications/Safari.app").resolvingSymlinksInPath().path)

    /// Chrome's own icon when it is installed, else a stand-in.
    static let chromeIcon: NSImage = {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            return NSWorkspace.shared.icon(forFile: url.resolvingSymlinksInPath().path)
        }
        return NSImage(systemSymbolName: "globe", accessibilityDescription: "Chrome") ?? NSImage()
    }()
}

// MARK: - Glass

/// The window's translucent backdrop: the desktop and windows behind show through.
private struct WindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private extension View {
    /// Liquid Glass on macOS 26 and later; a material card before that.
    @ViewBuilder
    func card(interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: 12))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func prominentButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    SettingsView()
}
