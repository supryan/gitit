# GitIt for Chrome

The same toolbar badge, popup and dashboard as the Safari extension, fed by the same
GitIt Mac app: the token stays in the app, and the extension never touches the network.

## Install

In GitIt's settings, under **Browser Extensions**, press **Install** next to Chrome. GitIt
puts the extension in `~/Library/Application Support/GitIt/GitIt for Chrome`, registers its
native host with Chrome, and walks you through the one step Chrome keeps for you: turn on
Developer mode in `chrome://extensions` and drag that folder onto the page (or press
**Load unpacked** and choose it). The row turns **Enabled** once the extension checks in.

### While developing

```sh
make chrome
```

builds the extension into `chrome/build/GitIt for Chrome` and registers the native host for
the installed GitIt; load that folder unpacked instead. After changing anything in `shared/`,
run it again and press the reload arrow on GitIt's card in `chrome://extensions`.

## How it fits together

| File | Does |
|---|---|
| `manifest.json` | Chrome's manifest; its `key` pins the extension id `mgcnmhlmcnjpabbdcpoflcejlojpmoap` |
| `background.js` | Asks the app for its result, keeps the badge, opens the dashboard |
| `build.sh` | Copies the popup, dashboard, theme and icons from `../shared` beside these two files |
| `install-host.sh` | Registers GitIt's executable as Chrome's native messaging host (`make chrome`) |

The popup and dashboard are shared with Safari, so change them in `shared/`. The native host
is GitIt's own executable: Chrome launches it with the extension's origin as its argument,
and it answers from the running app's latest result (`app/GitIt/ChromeNativeHost.swift`).

## The extension id

The `key` in `manifest.json` (a public key, safe to publish) pins the id to
`mgcnmhlmcnjpabbdcpoflcejlojpmoap` wherever the extension is loaded, and GitIt's native host
only answers that id. The matching private key is only needed to keep this id on a first
Chrome Web Store upload; it is not in the repo (`*.pem` is ignored).

