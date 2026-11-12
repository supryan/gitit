#!/bin/sh
# Waits for Apple's notary service to approve the uploaded archive, then exports the app
# with the approval stapled to it. Apple usually answers within a few minutes.
#
# Usage: scripts/fetch-notarized.sh <archive> <export folder>
set -u

archive=$1
out=$2
for attempt in $(seq 1 60); do
    if xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath "$out" >"$out.log" 2>&1; then
        echo "Notarized: $out/GitIt.app"
        exit 0
    fi
    if grep -qiE "rejected|invalid" "$out.log"; then
        echo "Apple rejected the app; details:" >&2
        cat "$out.log" >&2
        exit 1
    fi
    echo "Waiting for Apple's notary service… ($attempt)"
    sleep 30
done
echo "Gave up waiting after 30 minutes; run make release again later." >&2
exit 1
