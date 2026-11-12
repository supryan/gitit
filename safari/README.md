# GitIt for Safari

The Safari extension's own files. It ships inside the Mac app: the Xcode project in
[`../app`](../app/README.md) builds it from this folder plus the shared pages in
[`../shared`](../shared/README.md), so `make install` from the repo root is all it takes.

| File | Does |
|---|---|
| `manifest.json` | Safari's manifest (keep `version` equal to `MARKETING_VERSION` in `app/Config/Shared.xcconfig`) |
| `background.js` | Asks the app for its result on start and every minute, keeps the toolbar badge, opens the dashboard |
| `SafariWebExtensionHandler.swift` | Answers the extension's native messages from the app group the app writes |
| `toolbar-icon.svg` | The toolbar icon, a template Safari tints |
| `Info.plist`, `GitIt Extension.entitlements` | The extension target's bundle settings and its app group |

## How it talks to the app

The background script sends `{ type: "status" }` (or `"refresh"` for Check now) with
`browser.runtime.sendNativeMessage`. The handler answers with `{ available, hasToken, summary }`
from the app group; `"refresh"` also asks the running app to check at once. The extension
never holds the token and never calls GitHub.

Two things go the other way, through the same answer:

- **Dashboard address:** each request carries the dashboard's URL, which Safari picks at install. The handler saves it so the app knows the extension is set up.
- **Opening the dashboard:** Safari won't open an extension's page for another app, so the app's Dashboard button leaves a request and brings Safari forward. Safari's window gaining focus wakes the background script, and the next answer carries `openDashboard: true`.

## Working on it

Change the popup, dashboard or colours in [`../shared`](../shared/README.md); this folder is
only Safari's plumbing. After any change, run `make install` and quit and reopen Safari. With
an ad-hoc build (no Team ID), turn on **Develop > Allow Unsigned Extensions** first.
