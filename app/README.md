# GitIt for Mac

The Mac app. It does all the GitHub work, embeds the Safari extension (`../safari`, with the
pages from `../shared`), and carries the Chrome extension (`../chrome`) for Settings' Install
button. Features are in the [main README](../README.md).

## Install

Requires macOS 14+ and Xcode 16+.

```sh
git clone git@github.com:supryan/gitit.git && cd gitit
cp app/Config/Local.example.xcconfig app/Config/Local.xcconfig
make install
```

1. In `Local.xcconfig`, set `DEVELOPMENT_TEAM` to your Team ID (a free Personal Team works). Skip it to sign ad-hoc; Safari then needs **Develop > Allow Unsigned Extensions**.
2. Add that Apple ID in **Xcode > Settings > Accounts**. The build creates the certificate and profiles itself.
3. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt), paste it into GitIt's settings, and press Save.
4. Under **Browser Extensions**, press **Enable…** for Safari and **Install…** for Chrome.

To update, `git pull && make install`. Personal Team profiles expire after 7 days; reinstalling renews them.

## Commands

Run from the repo root or from `app/`.

| | |
|---|---|
| `make install` | Build, install to `~/Applications`, open; unregister any other GitIt copy |
| `make build` | Build Release into `app/build` (assembles the Chrome extension first) |
| `make icons` | Redraw the app and extension icons from `scripts/make-icons.swift` |
| `make clean` | Remove `app/build` |

## Layout

```
GitIt/      the app: polling, notifications, Keychain, settings, menu bar item,
            and the Chrome extension's native host (ChromeNativeHost.swift)
Config/     Shared.xcconfig (ids, signing defaults), plus your gitignored Local.xcconfig
scripts/    icon drawing, build output filter, keep-one-gitit.sh
```

The app's bundle id is `com.gitit.app` (it was `com.jickfive.gitit`; the first launch under
the new id copies settings and the token across, see `GitIt/Migration.swift`).

## Troubleshooting

- **Two GitIt extensions in Safari:** run `make install`, which unregisters every other copy, then quit and reopen Safari.
- **Token missing after reinstall:** a copy signed differently can't read the old Keychain item. Paste the token again.
