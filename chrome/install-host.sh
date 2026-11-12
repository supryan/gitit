#!/bin/sh
# Tells Chrome where GitIt's native messaging host is: GitIt's own executable, which
# answers the extension's requests from the running app's latest result
# (app/GitIt/ChromeNativeHost.swift). Only this extension may talk to it; its id
# comes from the key in manifest.json, the same way Chrome computes it.
#
# Usage: chrome/install-host.sh [/path/to/GitIt.app]    (default ~/Applications/GitIt.app)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
app=${1:-$HOME/Applications/GitIt.app}
executable="$app/Contents/MacOS/GitIt"
[ -x "$executable" ] || { echo "No GitIt at $app; run make install first." >&2; exit 1; }

# Chrome's extension id: the first 32 hex digits of the key's SHA-256, written a-p.
id=$(sed -n 's/.*"key": *"\([^"]*\)".*/\1/p' "$here/manifest.json" | base64 -d | shasum -a 256 | cut -c1-32 | tr 0-9a-f a-p)

hosts="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
mkdir -p "$hosts"
rm -f "$hosts/com.jickfive.gitit.json" # GitIt's old id
cat > "$hosts/com.gitit.app.json" <<EOF
{
    "name": "com.gitit.app",
    "description": "GitIt: hands the Chrome extension the GitIt app's latest result",
    "path": "$executable",
    "type": "stdio",
    "allowed_origins": [ "chrome-extension://$id/" ]
}
EOF
echo "Chrome may now reach GitIt from extension $id"
