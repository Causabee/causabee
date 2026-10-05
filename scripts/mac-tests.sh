#!/bin/zsh
# The Mac's regression tests: the unit tests, then the Mac app clicked through on the demo's
# matters (Tests/CausabeeAppUITests). scripts/release.sh runs this first and builds nothing if one
# fails; CAUSABEE_SKIP_TESTS=1 skips it there.
#
#   scripts/mac-tests.sh            # both
#   scripts/mac-tests.sh --unit     # the unit tests only — two seconds, no window
#
# The app clicked through is the Debug build, started as the demo on a store made for each test, so
# the owner's matters are never opened. It carries Causabee's own identifier, and a test starts and
# quits whatever runs under it: Causabee itself must be quit first — this script stops if it is open.
# While it runs, windows open and the pointer moves: the Mac is busy for a few minutes.
set -e -u -o pipefail
cd "$(dirname "$0")/.."

print "→ Running the unit tests"
swift test 2>&1 | tail -1
[[ ${1:-} == --unit ]] && exit 0

# Clicking through needs the Mac's Automation Mode, which its owner switches on once, with their
# password: `automationmodetool enable-automationmode-without-authentication`. Without it the test
# runner waits for a password window and gives up — so it is said here, and not tried.
if automationmodetool 2>/dev/null | grep -q "requires user authentication"; then
  print "  (not clicked through: this Mac asks for a password before a test may control it."
  print "   Once: automationmodetool enable-automationmode-without-authentication)"
  exit 0
fi

# By the program itself, not by the words of a command line: a shell that only names the path is not Causabee.
if ps -axo comm= | grep -q "Causabee.app/Contents/MacOS/Causabee$"; then
  print -u2 "✗ Causabee is open. Quit it first: the tests start and quit an app under its identifier."
  exit 1
fi

print "→ Clicking through the Mac app on the demo"
LOG=${TMPDIR:-/tmp}/causabee-mac-tests.log
xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeeAppUITests -destination 'platform=macOS' \
  -derivedDataPath .build-app/mactests -skipMacroValidation -allowProvisioningUpdates > "$LOG" 2>&1 \
  || { grep -E "error:|failed" "$LOG" | tail -15; print -u2 "✗ The Mac's regression tests failed. The whole log: $LOG"; exit 1 }
grep -E "Executed .* tests" "$LOG" | tail -1
print "✓ The Mac's regression tests passed."
