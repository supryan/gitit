# GitIt for Safari

The macOS app and Safari extension. Features are in the [main README](../README.md).

## Install

Requires macOS 14+ and Xcode 16+.

```sh
git clone git@github.com:supryan/gitit.git && cd gitit
cp safari/Config/Local.example.xcconfig safari/Config/Local.xcconfig
make install
```

1. In `Local.xcconfig`, set `DEVELOPMENT_TEAM` to your Team ID (a free Personal Team works). Skip it to sign ad-hoc; Safari then needs **Develop > Allow Unsigned Extensions**.
2. Add that Apple ID in **Xcode > Settings > Accounts**. The build creates the certificate and profiles itself.
3. Create a [classic token](https://github.com/settings/tokens/new?scopes=notifications,repo,read:org&description=GitIt), paste it into GitIt's settings, and press Save.
4. Turn GitIt on in **Safari > Settings > Extensions**.

To update, `git pull && make install`. Personal Team profiles expire after 7 days; reinstalling renews them.

## Commands

Run from the repo root or from `safari/`.

| | |
|---|---|
| `make install` | Build, install to `~/Applications`, open |
| `make build` | Build Release into `safari/build` |
| `make icons` | Redraw the icons from `scripts/make-icons.swift` |
| `make clean` | Remove `safari/build` |

## Layout

```
GitIt/              the app: polling, notifications, Keychain, settings, menu bar item
GitIt Extension/    the Safari extension: popup, dashboard, badge
Config/             Shared.xcconfig, plus your gitignored Local.xcconfig
scripts/            icon drawing and build output filter
```

## Troubleshooting

- **Two GitIt extensions in Safari:** delete any old `build/` folder outside `safari/`, then quit and reopen Safari.
- **Token missing after reinstall:** a copy signed differently can't read the old Keychain item. Paste the token again.
