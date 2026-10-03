#!/bin/zsh
# Sends the iPhone app to TestFlight: archives CausabeePhone and uploads it to App Store Connect,
# where the internal group gets it by itself once Apple has processed it.
#
#   scripts/testflight.sh 0.5 2      # version 0.5, build 2 — the build number must be new for that version
#
# Needs Xcode signed in to the Apple account of the team. Other place for the archive: CAUSABEE_RELEASE_DIR.
set -e -u -o pipefail
cd "$(dirname "$0")/.."

fail() { print -u2 "✗ $1"; exit 1 }
step() { print "→ $1" }

(( $# == 2 )) || { print -u2 "Usage: scripts/testflight.sh <version, like 0.5> <build, like 2>"; exit 64 }
VERSION=$1; BUILD=$2
OUT=${CAUSABEE_RELEASE_DIR:-$HOME/Library/Caches/causabee-release}/testflight-$VERSION-$BUILD
rm -rf "$OUT"; mkdir -p "$OUT"

cat > "$OUT/export.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>2F7QR8NL2D</string>
</dict></plist>
EOF

step "Archiving Causabee $VERSION ($BUILD) for the iPhone"
xcodebuild archive -project App/Causabee.xcodeproj -scheme CausabeePhone -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/CausabeePhone.xcarchive" -allowProvisioningUpdates \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" > "$OUT/archive.log" 2>&1 \
  || { tail -20 "$OUT/archive.log"; fail "The archive failed. The whole log: $OUT/archive.log" }

step "Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$OUT/CausabeePhone.xcarchive" -exportOptionsPlist "$OUT/export.plist" \
  -exportPath "$OUT/export" -allowProvisioningUpdates > "$OUT/export.log" 2>&1 \
  || { tail -20 "$OUT/export.log"; fail "The upload failed. The whole log: $OUT/export.log" }

print "✓ Causabee $VERSION ($BUILD) is uploaded. TestFlight shows it once Apple has processed it — usually 5 to 15 minutes."
