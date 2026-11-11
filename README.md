# GitIt

Everything on GitHub that's waiting on you (your open PRs, review requests, assigned issues/PRs and unread notifications) in your browser toolbar.

```
safari/   macOS app + Safari extension (Xcode project)
chrome/   Chrome extension (coming soon)
```

## Safari

- 🔔 **Native macOS notifications** for each new item; click one to open it on GitHub
- 🔢 **Toolbar badge** with the count of everything waiting on you
- 🗂️ **Popup** with Issues, PRs and Activity tabs, showing the most recent items
- 📋 **Dashboard** listing everything, grouped by why it needs you
- 🔄 **Background checks** every 1–60 minutes, or on demand with Check now
- 📍 **Optional menu bar icon** with the count and a quick list
- 🔒 **Private by design:** your token stays in the Keychain, and the extension never touches the network

**Install** (macOS 14+, Xcode 16+):

```sh
cp safari/Config/Local.example.xcconfig safari/Config/Local.xcconfig   # optional: add your Team ID
make install                                                            # builds, installs to ~/Applications, opens
```

Without a Team ID the app is signed ad-hoc and Safari needs **Develop > Allow Unsigned Extensions**.

**Setup:**

1. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt) with `notifications`, `repo`, `read:org`.
2. Paste it into GitIt's settings and press Save.
3. Turn GitIt on in **Safari > Settings > Extensions**.

## Chrome

Coming soon. Planned:

- 🔢 **Toolbar badge** with the count of everything waiting on you
- 🗂️ **Popup** with the same Issues, PRs and Activity tabs
- 📋 **Dashboard** listing everything, grouped by why it needs you
