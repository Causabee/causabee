#!/bin/zsh
# Builds Causabee and matter-spike and signs both with the owner's personal development
# certificate, under fixed identifiers. macOS ties "Always Allow" for the Keychain password to
# that signature, so it asks once — not again after every rebuild, as it does for unsigned builds.
set -e
cd "$(dirname "$0")/.."
swift build --product Causabee
swift build --product matter-spike
# Which certificate is the owner's own, not committed: one line in scripts/signing.local,
# for example `Apple Development: you@example.com`.
LOCAL="scripts/signing.local"
if [[ ! -f "$LOCAL" ]]; then echo "No $LOCAL naming the certificate — builds stay unsigned."; exit 0; fi
NAME=$(head -1 "$LOCAL")
IDENTITY=$(security find-identity -p codesigning -v | grep -F "$NAME" | awk '{print $2}' | head -1)
if [[ -z "$IDENTITY" ]]; then echo "No '$NAME' certificate — builds stay unsigned."; exit 0; fi
BIN=$(swift build --show-bin-path)
codesign --force --sign "$IDENTITY" --identifier de.chille.causabee "$BIN/Causabee"
codesign --force --sign "$IDENTITY" --identifier de.chille.causabee.spike "$BIN/matter-spike"
echo "Signed: $BIN/Causabee, $BIN/matter-spike"
