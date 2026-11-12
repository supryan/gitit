# <img src="app/GitIt/Assets.xcassets/AppIcon.appiconset/icon-256.png" alt="" width="44" align="absmiddle"> GitIt

Everything on GitHub that's waiting on you (your open PRs, review requests, assigned issues/PRs and unread notifications) in your menu bar, your notifications and your browser toolbar.

<p align="center">
  <img src="docs/settings.png" alt="GitIt's settings window" width="420">
  &nbsp;
  <img src="docs/popup.png" alt="GitIt's Safari extension popup" width="296">
</p>

## The Mac app

GitIt is a small macOS app that does the work: it checks GitHub in the background and feeds the browser extensions, so your token never leaves the app.

- 🔔 **Native notifications** for each new item; click one to open it on GitHub
- 📍 **Menu bar icon** in four styles (count, badge, dot or icon only), with a quick list grouped by why each item needs you
- 🔄 **Background checks** every 1–60 minutes, or on demand with Check Now
- 🧩 **Browser extensions** enabled and managed from one Settings window
- 🔒 **Private by design:** your token stays in the Keychain, and the extensions never touch the network

### Install

<p align="center">
  <a href="https://supryan.com/downloads/GitIt.zip"><img src="https://img.shields.io/badge/Download_GitIt-macOS_14%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="Download GitIt for macOS" height="44"></a>
</p>

> [!TIP]
> Unzip it, move **GitIt** to Applications and open it. It's signed and notarized by Apple, so it opens without any warnings.

1. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt) with `notifications`, `repo`, `read:org`.
2. Paste it into GitIt's settings and press Save.
3. Turn on the [browser extensions](#browser-extensions) you use.

## Browser extensions

### Features

- 🔢 **Toolbar badge** with the count of everything waiting on you
- 🗂️ **Popup** with Issues, PRs and Activity tabs, showing the most recent items
- 📋 **Dashboard** listing everything, grouped by why it needs you, with organization and project filters

**Safari**

In GitIt's settings, under **Browser Extensions**, press **Enable** next to Safari and turn GitIt on.

**Chrome**

In GitIt's settings, under **Browser Extensions**, press **Install** next to Chrome. Then in `chrome://extensions`, turn on **Developer mode** and drag in the **GitIt for Chrome** folder the app shows you. More in [`chrome/README.md`](chrome/README.md).

## Contributing

GitIt is open source, and issues and pull requests are welcome. Building and the code's layout are covered in [`app/README.md`](app/README.md), with notes for each part in [`safari/`](safari/README.md), [`chrome/`](chrome/README.md) and [`shared/`](shared/README.md).

## License

[MIT](LICENSE) © Ryan Gordon
