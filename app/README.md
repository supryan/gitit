# GitIt for Mac

The Mac app, and the place to start when working on GitIt. It does all the GitHub work,
embeds the Safari extension (`../safari`, with the pages from `../shared`), and carries the
Chrome extension (`../chrome`) for Settings' Install button. Features are in the
[main README](../README.md).

## Building from source

Requires macOS 14+ and Xcode 16+.

```sh
git clone https://github.com/supryan/gitit.git && cd gitit
cp app/Config/Local.example.xcconfig app/Config/Local.xcconfig   # optional: your Team ID
make install                                                     # builds, installs to ~/Applications, opens
```

1. In `Local.xcconfig` (gitignored), set `DEVELOPMENT_TEAM` to your Team ID; a free Personal Team works. Skip it to sign ad-hoc, and Safari then needs **Develop > Allow Unsigned Extensions**.
2. Add that Apple ID in **Xcode > Settings > Accounts**. The build creates the certificate and profiles itself.
3. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt), paste it into GitIt's settings, and press Save.
4. Under **Browser Extensions**, press **Enable** for Safari and **Install** for Chrome.

To update, `git pull && make install`. Personal Team profiles expire after 7 days; reinstalling renews them.

## How it fits together

```
app/      this: the Mac app (Xcode project)
safari/   the Safari extension's own files (manifest, background script, native handler)
chrome/   the Chrome extension's own files (manifest, service worker, build scripts)
shared/   the popup, dashboard, theme and icons both extensions use
```

- **The app does all the GitHub work.** It holds the token in the Keychain, polls the REST API, posts notifications, and leaves its latest result in an app group.
- **The extensions only read that result**, over native messaging: Safari through `safari/SafariWebExtensionHandler.swift`, Chrome through GitIt's own executable (`GitIt/ChromeNativeHost.swift`). Neither holds the token or makes network requests.
- **The UI is shared:** both extensions use the pages in `shared/`.

In this folder:

```
GitIt/      the app: polling (Monitor, GitHubClient), notifications, Keychain, settings,
            menu bar item (StatusItem), Chrome support (ChromeExtension, ChromeNativeHost)
Config/     Shared.xcconfig (ids, versions, signing defaults), ExportOptions.plist (releases),
            plus your gitignored Local.xcconfig
scripts/    icon drawing, build output filter, keep-one-gitit.sh, fetch-notarized.sh
```

The app's bundle id is `com.gitit.app`; the Safari extension's is `com.gitit.app.Extension`.

## Commands

Run from the repo root or from `app/`.

| Command | Does |
|---|---|
| `make install` | Build, install to `~/Applications`, open; unregister any other GitIt copy |
| `make build` | Build Release into `app/build` (assembles the Chrome extension first) |
| `make chrome` | Build the Chrome extension to load unpacked (repo root only; see [`chrome/`](../chrome/README.md)) |
| `make icons` | Redraw the app and extension icons from `scripts/make-icons.swift` |
| `make release` | Build a signed, notarized `GitIt.zip` for download |
| `make publish` | Copy that zip to the site that hosts the download |
| `make clean` | Remove `app/build` |

## Releasing

`make release` archives the app, exports it with a **Developer ID** (Xcode manages the
certificate), sends it to Apple's notary service, waits for the approval and staples it, then
zips the result to `app/build/release.noindex/GitIt.zip`. It needs a paid Apple Developer
team; pass yours with `make release RELEASE_TEAM=<team id>`. Signed this way, GitIt opens
without warnings and Safari runs its extension as is.

`make publish` copies the zip into `../supryan-v2/public/downloads` (`SITE=<path>` to change
where); deploy that site to put it online.

Bump `MARKETING_VERSION` in `Config/Shared.xcconfig` and `version` in both extension
manifests together; Safari compares them.

## Good to know

- **One copy only:** `make install` unregisters every other GitIt that macOS knows about (old build folders, scratch builds), so Safari and Spotlight never list two. Builds go to `*.noindex` folders, which Spotlight skips.
- **GitHub API limits:** search allows 30 requests a minute. A check makes a few per category, more when there are over 100 results, so one minute is the shortest sensible interval.
- **Settings and the token** are kept per bundle id: the token in the login keychain, everything else in the app's preferences and its app group.

## Troubleshooting

- **Two GitIt extensions in Safari:** run `make install`, which unregisters every other copy, then quit and reopen Safari.
- **Token missing after reinstall:** a copy signed differently can't read the old Keychain item. Paste the token again.
