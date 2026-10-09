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

# Can it work at all? An app in full screen on the main screen, or a screen too small: said here,
# with what to do, and nothing is started — a run in that state fails in a dozen misleading ways.
print "→ Checking that the Mac's screen is free for the tests"
swift scripts/mac-preflight.swift || { print -u2 "✗ Not clicked through: put right what is named above, then run this again."; exit 1 }

LOG=${TMPDIR:-/tmp}/causabee-mac-tests.log
# What a failed run saw, said at once: the last picture of its screen recording and the windows
# in front — so the reason is looked at, not guessed and tried again.
evidence() {
  local result=$(ls -dt .build-app/mactests/Logs/Test/*.xcresult 2>/dev/null | head -1) out=${TMPDIR:-/tmp}/causabee-mac-tests-evidence
  grep -E "error:|failed" "$LOG" | tail -15
  mkdir -p "$out"
  if [[ -n $result ]] && xcrun xcresulttool export attachments --path "$result" --output-path "$out" > /dev/null 2>&1; then
    local film=$(ls -t "$out"/*.mp4 2>/dev/null | head -1)
    if [[ -n $film ]] && command -v ffmpeg > /dev/null; then
      ffmpeg -v error -y -sseof -0.6 -i "$film" -frames:v 1 "$out/last-picture.png" && print -u2 "  The screen as the failed test left it: $out/last-picture.png"
    fi
  fi
  swift scripts/mac-preflight.swift >&2 || true
  print -u2 "✗ The Mac's regression tests failed. Look at the picture before anything is changed or run again. The whole log: $LOG"
}
# A test may take a minute and a half, not four: one that hangs is ended, and says so.
run() {
  xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeeAppUITests -destination 'platform=macOS' \
    -derivedDataPath .build-app/mactests -skipMacroValidation -allowProvisioningUpdates \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 90 "$@" > "$LOG" 2>&1
}

# First one test alone, half a minute: is the window there to be clicked? If not, the eleven others
# are not run to fail one after the other.
print "→ One test first: can the window be clicked?"
run -only-testing:CausabeeAppUITests/ToolbarTests/testTheNameIsNeverUnderTheControls || { evidence; exit 1 }

print "→ Clicking through the Mac app on the demo"
run -skip-testing:CausabeeAppUITests/ToolbarTests/testTheNameIsNeverUnderTheControls || { evidence; exit 1 }
grep -E "Executed .* tests" "$LOG" | tail -1
print "✓ The Mac's regression tests passed."
