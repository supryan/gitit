# Shared extension pages

The popup, dashboard, theme and icons that both the [Safari](../safari/README.md) and
[Chrome](../chrome/README.md) extensions use. Change them here, once.

| File | Does |
|---|---|
| `popup.html`, `popup.css`, `popup.js` | The toolbar popup: Issues, PRs and Activity tabs |
| `dashboard.html`, `dashboard.css`, `dashboard.js` | The full list, with status chips and organization and project filters |
| `theme.css` | Base colours, the status colours, and the dots and tags that use them |
| `status.js` | The tag for each item, and `browser` mapped to Chrome's `chrome` API; load it first |
| `icons/` | The extension icons, drawn by `app/scripts/make-icons.swift` (`make icons`) |

## Notes

- **Status colours** are defined twice, in `theme.css` and in the app's `app/GitIt/StatusColors.swift` (Settings tiles, menu dots). Change both together.
- **Set font sizes explicitly.** Chrome's popup did not pass the root's base size down to inherited text, so `body` sets it too, and text that matters gives its own size.
- **Hidden files are skipped** by both builds (the Xcode project's exceptions and `chrome/build.sh`), so stray `.DS_Store` files or tool folders never ship.

## Seeing changes

- **Safari:** `make install`, then quit and reopen Safari.
- **Chrome:** `make chrome`, then press reload on GitIt's card in `chrome://extensions`.
