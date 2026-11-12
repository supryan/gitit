#!/bin/sh
# Leaves exactly one GitIt registered with macOS: the copy given as $1 (the installed one).
#
# Every other GitIt.app that Launch Services knows about (old build folders, scratch
# builds in temp folders, copies since deleted) is unregistered, and so is its Safari
# extension; otherwise Safari and Spotlight list each copy as another GitIt, and Safari
# may even run the extension from a stale build.
#
# Usage: scripts/keep-one-gitit.sh /path/to/GitIt.app    (or "" to unregister them all)
set -u

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
KEEP=${1:-}
EXTENSION="Contents/PlugIns/GitIt Extension.appex"

# Each registered bundle is a block in the dump; take the GitIt.app paths whose block
# carries GitIt's bundle identifier, current (com.gitit.app) or old (com.jickfive.gitit).
"$LSREGISTER" -dump 2>/dev/null | awk '
    /^-{20,}/ { if (path != "" && (id == "com.gitit.app" || id == "com.jickfive.gitit")) print path; path = ""; id = "" }
    /^path:/ { sub(/^path:[ \t]*/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); path = $0 }
    /^identifier:/ { sub(/^identifier:[ \t]*/, ""); id = $0 }
    END { if (path != "" && (id == "com.gitit.app" || id == "com.jickfive.gitit")) print path }
' | sort -u | while IFS= read -r app; do
    [ "$app" = "$KEEP" ] && continue
    echo "Unregistering $app"
    pluginkit -r "$app/$EXTENSION" 2>/dev/null || true
    "$LSREGISTER" -u "$app" 2>/dev/null || true
done

if [ -n "$KEEP" ]; then
    "$LSREGISTER" -f "$KEEP"
    pluginkit -a "$KEEP/$EXTENSION" 2>/dev/null || true
fi
