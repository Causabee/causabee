#!/bin/zsh
# The website's Mac pictures, taken again from the demo and cut for the site — one run, for when the
# design has changed:
#
#   scripts/site-shots.sh           # builds CausabeeDemo, photographs it, cuts the pictures
#   scripts/site-shots.sh --reuse   # with the app built last time
#
# What it does, and what was learned doing it by hand:
# - scripts/intro-shots.sh builds the Release app as CausabeeDemo, under an identifier of its own:
#   beside the owner's Causabee, open at the same time, a second app under Causabee's identifier is
#   given no window. It starts it once per picture with `--demo --shot <name>`, Auto off, and
#   `-NSTreatUnknownArgumentsAsOpen NO` — or macOS takes the shot's name for a file to open and
#   gives the app no window either. The terminal must be allowed to record the screen.
# - scripts/site-assets.py --pictures cuts site/assets/img from scripts/shots, with Pillow from a
#   small environment of its own under .build-app (nothing is installed into the system's Python).
#
# Afterwards, by hand: the animations over the pictures in site/index.html are measured in the
# pictures' own pixels. When the layout under them has moved — a bar higher, a tab narrower — the
# crops in site-assets.py and the `--x/--y` of the overlays move with it; look at the page
# (python3 -m http.server --directory site) before pushing, and raise the `?v=` of what changed.
# The iPhone's three pictures are taken in the simulator and are not part of this.
set -e -u -o pipefail
cd "$(dirname "$0")/.."

scripts/intro-shots.sh "$@"
ENV=.build-app/site-env
if [[ ! -x $ENV/bin/python ]]; then
  print "→ A Python with Pillow, in $ENV"
  python3 -m venv $ENV
  $ENV/bin/pip -q install pillow
fi
print "→ Cutting the website's pictures"
$ENV/bin/python scripts/site-assets.py --pictures | grep "img/" || true
print "✓ site/assets/img — now look at the page: the animations over the pictures are measured by hand."
