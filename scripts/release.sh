#!/bin/zsh
# Makes a Matterbee release: builds the app, signs it with a Developer ID, has Apple notarize it, puts
# it in a disk image (drag to Applications), puts that on GitHub as a release, and points the
# website's download buttons at it.
#
#   scripts/release.sh 0.4.0-beta.1              # asks once before anything is published
#   scripts/release.sh 0.4.0-beta.1 --dry-run    # builds, signs, makes the disk image; sends and publishes nothing
#   scripts/release.sh 0.4.0-beta.1 --notes whats-new.md --yes
#
# A version with -beta.N (or -alpha.N, -rc.N) becomes a pre-release. Without --notes, the notes are
# scripts/release-notes.md ({{FILE}} in them becomes the disk image's name); either way the disk
# image's SHA-256 is added at the end. The disk image is made by scripts/dmg/make-dmg.sh.
#
# Needs, once: a "Developer ID Application" certificate in the Keychain, and the notary login saved as
#   xcrun notarytool store-credentials "matterbee-notary" --apple-id <you> --team-id <team>
# Other names: MATTERBEE_NOTARY_PROFILE, MATTERBEE_DEVELOPER_ID. It builds App/Matterbee.xcodeproj.
#
# A release is signed without the iCloud entitlement (scripts/release.entitlements): Xcode makes no
# Developer ID profile for it from the command line, so a release keeps its matters on the Mac.
set -e -u -o pipefail
cd "$(dirname "$0")/.."

fail() { print -u2 "✗ $1"; exit 1 }
step() { print "→ $1" }

usage() { print -u2 "Usage: scripts/release.sh <version, like 0.4.0-beta.1> [--dry-run] [--notes file.md] [--yes]"; exit 64 }
(( $# >= 1 )) || usage
VERSION=$1; shift
DRY=false; YES=false; NOTES=""
while (( $# )); do
  case $1 in
    --dry-run) DRY=true ;;
    --yes) YES=true ;;
    --notes) (( $# >= 2 )) || usage; NOTES=$2; shift ;;
    *) usage ;;
  esac
  shift
done

# 0.4.0-beta.1 → tag v0.4.0-beta.1, "Matterbee 0.4 Beta 1", Matterbee-0.4-beta.1.dmg, the app's version 0.4.
[[ $VERSION =~ '^([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta|rc)\.([0-9]+))?$' ]] || fail "A version looks like 0.4.0 or 0.4.0-beta.1, not '$VERSION'."
MAJOR=$match[1]; MINOR=$match[2]; PATCH=$match[3]; KIND=${match[5]:-}; NUMBER=${match[6]:-}
SHORT="$MAJOR.$MINOR"; [[ $PATCH == 0 ]] || SHORT+=".$PATCH"
TAG="v$VERSION"
if [[ -n $KIND ]]; then
  WORD=${(C)KIND}; [[ $KIND == rc ]] && WORD="RC"
  TITLE="Matterbee $SHORT $WORD $NUMBER"; LABEL="Version $SHORT $WORD $NUMBER"; DMG_NAME="Matterbee-$SHORT-$KIND.$NUMBER.dmg"; PRE=(--prerelease)
else
  TITLE="Matterbee $SHORT"; LABEL="Version $SHORT"; DMG_NAME="Matterbee-$SHORT.dmg"; PRE=()
fi
DMG=.build-app/release/$TAG/$DMG_NAME

PROFILE=${MATTERBEE_NOTARY_PROFILE:-matterbee-notary}
IDENTITY=${MATTERBEE_DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}
[[ -n $IDENTITY ]] || fail "No 'Developer ID Application' certificate in the Keychain."
[[ -d App/Matterbee.xcodeproj ]] || fail "No App/Matterbee.xcodeproj on this Mac."

# Before building: the release is made from main as it is on GitHub, under a tag that is still free.
step "Checking git, GitHub and the notary login"
git fetch -q origin
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $BRANCH != main || -n $(git status --porcelain) || $(git rev-parse HEAD) != $(git rev-parse origin/main) ]]; then
  $DRY || fail "Releases are made from a clean main that matches origin/main (now: $BRANCH$([[ -n $(git status --porcelain) ]] && print ', with changes'))."
  print "  (dry run: not on a clean, pushed main — building what is here)"
fi
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
if [[ -n $(git ls-remote --tags origin "refs/tags/$TAG") ]] || gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  fail "$TAG exists already on $REPO."
fi
$DRY || xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 || fail "No notary login saved as '$PROFILE' (see the top of this script)."

OUT=.build-app/release/$TAG
APP=$OUT/Matterbee.app
rm -rf "$OUT"; mkdir -p "$OUT"

step "Building $TITLE (Release)"
BUILD=$(date +%Y%m%d%H%M)
xcodebuild archive -project App/Matterbee.xcodeproj -scheme MatterbeeApp -configuration Release \
  -archivePath "$OUT/Matterbee.xcarchive" -allowProvisioningUpdates \
  MARKETING_VERSION="$SHORT" CURRENT_PROJECT_VERSION="$BUILD" > "$OUT/build.log" 2>&1 \
  || { tail -25 "$OUT/build.log"; fail "The build failed; all of it is in $OUT/build.log."; }
ditto "$OUT/Matterbee.xcarchive/Products/Applications/Matterbee.app" "$APP"
[[ $(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist") == "$SHORT" ]] || fail "The app does not say version $SHORT."

step "Signing with $IDENTITY"
# The development profile lists the owner's registered Macs; a download has no use for it.
rm -f "$APP/Contents/embedded.provisionprofile"
codesign --force --options runtime --timestamp --entitlements scripts/release.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP" || fail "The signature does not verify."

# The disk image: the app, the Applications folder beside it, and the picture that says to drag.
disk_image() {
  step "Making the disk image"
  scripts/dmg/make-dmg.sh "$APP" "$DMG" "$TITLE" > /dev/null
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  codesign --verify "$DMG" || fail "The disk image's signature does not verify."
}

# Sends a file to Apple's notary and waits; stops the release with Apple's log if it is not accepted.
notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait --output-format json > "$OUT/notary.json" || true
  local result=$(plutil -extract status raw -o - "$OUT/notary.json" 2>/dev/null || print "no answer")
  if [[ $result != Accepted ]]; then
    local id=$(plutil -extract id raw -o - "$OUT/notary.json" 2>/dev/null || true)
    [[ -n $id ]] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" | tail -30
    fail "Apple did not accept $2: $result."
  fi
}

if $DRY; then
  disk_image
  print "✓ Dry run done: $DMG — signed, not notarized, nothing published."
  exit 0
fi

# The app first, so it carries its own ticket once it is in Applications; then the disk image around it.
step "Notarizing the app (Apple usually answers within a few minutes)"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
notarize "$OUT/notarize.zip" "the app"
xcrun stapler staple -q "$APP"
spctl -a -t exec -vv "$APP" 2>&1 | grep -q "Notarized Developer ID" || fail "Gatekeeper does not see the app as notarized."
rm "$OUT/notarize.zip"
disk_image
step "Notarizing the disk image"
notarize "$DMG" "the disk image"
xcrun stapler staple -q "$DMG"
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | grep -q "Notarized Developer ID" || fail "Gatekeeper does not see the disk image as notarized."
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)

{ sed -e "s|{{FILE}}|$DMG_NAME|g" -e "s|{{ZIP}}|$DMG_NAME|g" "${NOTES:-scripts/release-notes.md}"; print "\nSHA-256 of the disk image: \`$SHA\`"; } > "$OUT/notes.md"

print "\n  Release   $TITLE ($TAG)$([[ -n $KIND ]] && print ', pre-release')"
print "  File      $DMG_NAME, $(du -h "$DMG" | cut -f1 | tr -d ' ')"
print "  SHA-256   $SHA"
print "  Notes     $OUT/notes.md"
print "  Where     github.com/$REPO, and the website's download buttons\n"
if ! $YES; then
  read -q "?Publish it? [y/N] " || { print "\nNothing published. The notarized app is in $OUT."; exit 0 }
  print
fi

step "Publishing on GitHub"
gh release create "$TAG" "$DMG" -R "$REPO" --target main --title "$TITLE" --notes-file "$OUT/notes.md" $PRE

step "Pointing the website at it"
sed -E -i '' \
  -e "s#releases/download/v[^/\"]+/Matterbee-[^\"]+\.(zip|dmg)#releases/download/$TAG/$DMG_NAME#g" \
  -e "s#releases/tag/v[^\"]+#releases/tag/$TAG#g" \
  -e "s#Version [0-9]+(\.[0-9]+)+( (Alpha|Beta|RC) [0-9]+)?#$LABEL#g" \
  site/index.html
if git diff --quiet site/index.html; then
  print "  The website's links named nothing to change — check site/index.html by hand."
else
  git add site/index.html
  git commit -q -m "The website's download buttons fetch $TITLE"
  git push -q origin main
fi

print "✓ $TITLE is out: https://github.com/$REPO/releases/tag/$TAG"
