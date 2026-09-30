#!/bin/zsh
# Makes scripts/dmg/background.tiff from background.html: the picture at 660 × 400 and at twice that,
# in one file, so the disk image's window is sharp on every screen. Needs Google Chrome; only run it
# when background.html changes — the release uses the .tiff that is in git.
set -e -u -o pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x $CHROME ]] || { print -u2 "✗ Needs Google Chrome in /Applications."; exit 1 }
TMP=$(mktemp -d)
trap 'pkill -f "$TMP/profile" 2>/dev/null; rm -rf "$TMP"' EXIT

# Chrome writes the screenshot but does not always quit afterwards: wait for the file, then end it.
shot() {
  "$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=$1 --window-size=660,400 \
    --virtual-time-budget=3000 --user-data-dir="$TMP/profile" --screenshot="$2" "file://$PWD/background.html" \
    >/dev/null 2>&1 &
  for _ in {1..60}; do [[ -s $2 ]] && break; sleep 0.5; done
  sleep 1; pkill -f "$TMP/profile" 2>/dev/null || true
  [[ -s $2 ]] || { print -u2 "✗ Chrome made no picture."; exit 1 }
}
shot 1 "$TMP/background.png"
shot 2 "$TMP/background@2x.png"
tiffutil -cathidpicheck "$TMP/background.png" "$TMP/background@2x.png" -out background.tiff >/dev/null
print "✓ scripts/dmg/background.tiff"
