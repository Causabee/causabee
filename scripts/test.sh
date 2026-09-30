#!/usr/bin/env bash
# Everything that has to be green before a commit.
set -euo pipefail
cd "$(dirname "$0")/.."

# The filter drops one known line; the build's own result still decides (a failed build stops here).
swift build 2>&1 | grep -v "Source files for target MatterCoreTests" || [ "${PIPESTATUS[0]}" -eq 0 ]
swift test "$@"
