#!/bin/zsh
# Puts Causabee into a disk image the usual Mac way: its window shows the app on the left and the
# Applications folder on the right, on scripts/dmg/background.tiff, so one drag installs it.
#
#   scripts/dmg/make-dmg.sh <Causabee.app> <out.dmg> "<volume name>"
#
# Finder arranges the window, so the first run asks once whether this Terminal may control Finder.
# The image is not signed here: scripts/release.sh signs and notarizes it.
set -e -u -o pipefail
(( $# == 3 )) || { print -u2 "Usage: scripts/dmg/make-dmg.sh <Causabee.app> <out.dmg> \"<volume name>\""; exit 64 }
APP=${1:A}; OUT=${2:A}; VOL=$3
HERE=${0:A:h}
[[ -d $APP ]] || { print -u2 "✗ No app at $APP."; exit 1 }
[[ ! -e "/Volumes/$VOL" ]] || { print -u2 "✗ A disk named “$VOL” is open: eject it first."; exit 1 }

TMP=$(mktemp -d)
MNT=""
trap '[[ -n $MNT ]] && hdiutil detach -quiet -force "$MNT" 2>/dev/null; rm -rf "$TMP"' EXIT

# What the disk holds: the app, a link to /Applications, the picture and the disk's own icon (hidden).
mkdir -p "$TMP/stage/.background"
ditto "$APP" "$TMP/stage/Causabee.app"
ln -s /Applications "$TMP/stage/Applications"
cp "$HERE/background.tiff" "$TMP/stage/.background/background.tiff"
ICON=$(print -l "$APP"/Contents/Resources/*.icns(N) | head -1)

SIZE=$(( $(du -sm "$TMP/stage" | cut -f1) + 20 ))
hdiutil create -quiet -srcfolder "$TMP/stage" -volname "$VOL" -fs HFS+ -format UDRW -size ${SIZE}m "$TMP/rw.dmg"
# hdiutil's "attach is deprecated" note is not an error: it still does the job, and says so on stderr.
MNT=$(hdiutil attach "$TMP/rw.dmg" -readwrite -noverify -noautoopen 2> >(grep -v deprecated >&2) | awk -F'\t' '/Apple_HFS/ { print $NF }')
[[ -d $MNT ]] || { print -u2 "✗ The disk image did not open."; exit 1 }

# 660 × 400 inside, plus the title bar; icons at 128 points where the picture expects them.
osascript <<EOF
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 548}
    set options to the icon view options of container window
    set arrangement of options to not arranged
    set icon size of options to 128
    set text size of options to 13
    set background picture of options to file ".background:background.tiff"
    set position of item "Causabee.app" of container window to {170, 170}
    set position of item "Applications" of container window to {490, 170}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF

# The disk's own icon comes last: Finder's "update" above deletes one that is already there.
if [[ -n $ICON ]]; then cp "$ICON" "$MNT/.VolumeIcon.icns"; SetFile -a C "$MNT"; fi

# Finder writes the window's layout (.DS_Store) when it closes it: give it a moment, then seal the disk.
sync; sleep 2
hdiutil detach -quiet "$MNT"; MNT=""
rm -f "$OUT"
hdiutil convert -quiet "$TMP/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$OUT"
print "✓ $OUT"
