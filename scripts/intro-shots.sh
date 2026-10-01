#!/bin/zsh
# Takes the introduction's five pictures again, from the demo, for when the design has changed:
# App/Resources/Intro/intro-1…5.png, 1800 × 1125, and the same at the window's full Retina size,
# 2880 × 1800, as scripts/shots/intro-1…5.png — the website's pictures are cut from those, so they
# stay sharp on a Retina screen (they are not in App/Resources: all of that goes into the app). Each one is its own run of the Release app with
# `--demo --shot <name>` on a fresh demo store of its own, so the owner's matters are never in them,
# and only that window is photographed.
#
#   scripts/intro-shots.sh          # then: python3 scripts/site-assets.py, for the website's pictures
#   scripts/intro-shots.sh --reuse  # with the Release app built last time, if it is there
#
# The window must be on a Retina screen (2x); the first run may ask to allow screen recording.
set -e -u -o pipefail
cd "$(dirname "$0")/.."

APP="$PWD/.build-app/shots/Build/Products/Release/Matterbee.app"
if [[ ${1:-} != --reuse || ! -d $APP ]]; then
  print "→ Building the Release app"
  # A build folder of its own: the owner's Release app may be running from .build-app, and must not be
  # replaced under it.
  xcodebuild -project App/Matterbee.xcodeproj -scheme MatterbeeApp -configuration Release -derivedDataPath .build-app/shots \
    -allowProvisioningUpdates -skipMacroValidation build -quiet > /dev/null
fi
mkdir -p scripts/shots
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SHOTS=(overview lisbon lisbon-tasks lisbon-files care)

for i in {1..5}; do
  shot=$SHOTS[$i]
  print "→ intro-$i: $shot"
  mkdir -p "$TMP/$shot"
  # Opened as an app, not run from this shell: then it is in front, and macOS gives it Matterbee's own
  # Calendar and Reminders access, so the dates show "Add to Calendar" (the demo still adds nothing).
  open -n -a "$APP" --args --store "$TMP/$shot/matters.store" --demo --shot "$shot"
  for _ in {1..20}; do pid=$(pgrep -n -f -- "--shot $shot" || true); [[ -n $pid ]] && break; sleep 0.25; done
  [[ -n $pid ]] || { print -u2 "✗ Matterbee did not start for $shot."; exit 1 }
  # The demo fills its store, opens the matter, scrolls, and a marked to-do fades again.
  sleep 6
  id=$(swift scripts/window-id.swift $pid) || { kill $pid; print -u2 "✗ No window for $shot."; exit 1 }
  screencapture -x -o -l "$id" "$TMP/$shot.png"
  kill $pid; while kill -0 $pid 2>/dev/null; do sleep 0.2; done
  size=$(sips -g pixelWidth -g pixelHeight "$TMP/$shot.png" | awk '/pixel/ {print $2}' | paste -sd x -)
  [[ $size == 2880x1800 ]] || print "  (the window came out $size, not 2880x1800 — scaled anyway)"
  sips -z 1800 2880 "$TMP/$shot.png" --out "scripts/shots/intro-$i.png" > /dev/null
  sips -z 1125 1800 "$TMP/$shot.png" --out "App/Resources/Intro/intro-$i.png" > /dev/null
done
print "✓ App/Resources/Intro/intro-1…5.png and scripts/shots/intro-1…5.png — now python3 scripts/site-assets.py for the website"
