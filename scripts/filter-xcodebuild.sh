#!/bin/sh
# Keeps xcodebuild's output to what matters: errors, warnings, and the verdict.
# Exits with xcodebuild's status (pipefail is not portable, so the verdict line decides).
status=0
while IFS= read -r line; do
    case "$line" in
        *"error:"*|*"warning:"*|*"** BUILD "*|*"The following build commands failed"*|*"note: "*"To sign"*)
            printf '%s\n' "$line" ;;
    esac
    case "$line" in
        *"** BUILD FAILED **"*) status=1 ;;
    esac
done
exit $status
