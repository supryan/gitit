# GitIt

Everything on GitHub that's waiting on you, in your menu bar and Safari toolbar.

- **Menu bar app** polls GitHub and posts macOS notifications for new items.
- **Safari extension** badges the count; the popup has Issues, PRs and Activity tabs, plus a full dashboard.
- Covers your open PRs, review requests, assigned issues/PRs and unread notifications.
- Your token stays in the Keychain. The extension never touches the network.

> **Chrome extension coming soon.**

## Install

Requires macOS 14+ and Xcode 16+.

```sh
cp Config/Local.example.xcconfig Config/Local.xcconfig   # optional: add your Team ID
make install                                              # builds, installs to ~/Applications, opens
```

Without a Team ID the app is signed ad-hoc and Safari needs **Develop > Allow Unsigned Extensions**.

## Setup

1. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt) with `notifications`, `repo`, `read:org`.
2. Paste it into GitIt's settings and press Save.
3. Turn GitIt on in **Safari > Settings > Extensions**.
