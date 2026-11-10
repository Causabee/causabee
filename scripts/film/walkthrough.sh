#!/bin/zsh
# The website's film "One day with Causabee", drawn again from its page (site/film/walkthrough/index.html)
# with Safari's engine, after a change to the page:
#
#   scripts/film/walkthrough.sh            # renders the frames, makes both films and the poster
#   scripts/film/walkthrough.sh --reuse    # with the frames rendered last time
#
# The voice (voice.mp3, Carolyn's reading, never changed) and the page share one timing, timing.json,
# written by scripts/film/time-voice.py: the film lasts what it says, and never more than 129.6 s.
# The sound is mixed anew from the voice by soundtrack.py, each effect on its word. Each film carries
# the page's SHA-256 in its comment, so the tests can tell it was drawn from today's page. Needs ffmpeg
# (brew install ffmpeg), and Pillow, NumPy and SciPy — for the WebP poster and the sound — in the
# small environment site-shots.sh uses.
# Nothing in site/ is replaced until every step has worked.
set -e -u -o pipefail
cd "$(dirname "$0")/../.."

fail() { print -u2 "✗ $1"; exit 1 }
step() { print "→ $1" }

FILM=site/film/walkthrough
PAGE=$FILM/index.html
SECONDS_LONG=$(python3 -c "import json; print(json.load(open('$FILM/timing.json'))['total'])")
LONGEST=129.6
POSTER_AT=5.0
WORK=${CAUSABEE_FILM_DIR:-$HOME/Library/Caches/causabee-film}/walkthrough
FRAMES=$WORK/frames
command -v ffmpeg >/dev/null || fail "No ffmpeg: brew install ffmpeg."
ENV=.build-app/site-env
if [[ ! -x $ENV/bin/python ]]; then
  step "A Python with Pillow, in $ENV"
  python3 -m venv $ENV
fi
$ENV/bin/python -c "import PIL, numpy, scipy" 2>/dev/null || $ENV/bin/pip -q install pillow numpy scipy
mkdir -p $WORK

awk -v d=$SECONDS_LONG -v most=$LONGEST 'BEGIN { exit !(d <= most) }' || fail "The timing makes the film $SECONDS_LONG s, longer than $LONGEST: nothing is replaced."
FRAMES_WANTED=$(python3 -c "print(round($SECONDS_LONG * 30))")

step "Mixing the sound: the voice, the music and the effects, $SECONDS_LONG s"
ffmpeg -v error -y -i $FILM/voice.mp3 -ar 48000 -ac 1 $WORK/voice.wav
$ENV/bin/python $FILM/soundtrack.py $WORK/sound.wav $WORK/voice.wav
ffmpeg -v error -y -i $WORK/sound.wav -c:a aac -b:a 192k $WORK/sound.m4a

if [[ ${1:-} != --reuse ]]; then
  step "Drawing $FRAMES_WANTED frames of $PAGE (Safari's engine, 1920 × 1080)"
  rm -rf $FRAMES
  swift scripts/film/render.swift $PAGE $FRAMES $SECONDS_LONG 30 --size 1920x1080 --ms --root site --query render 2>&1 | grep -E "^frame|^rendered|failed|cannot" || true
fi
COUNT=$(ls $FRAMES | grep -c '^f.*\.png$' || true)
(( COUNT == FRAMES_WANTED )) || fail "$COUNT frames, not $FRAMES_WANTED: nothing is replaced."

SHA=$(shasum -a 256 $PAGE | cut -d' ' -f1)
step "Making the 1080p film"
ffmpeg -v error -y -framerate 30 -i $FRAMES/f%05d.png -i $WORK/sound.m4a -map 0:v -map 1:a -c:v libx264 -preset slow -crf 20 \
  -pix_fmt yuv420p -c:a copy -metadata comment="page-sha256:$SHA" -movflags +faststart $WORK/walkthrough.mp4
step "Making the 720p film"
ffmpeg -v error -y -i $WORK/walkthrough.mp4 -map 0 -vf scale=1280:720:flags=lanczos -c:v libx264 -preset slow -crf 27 \
  -pix_fmt yuv420p -c:a copy -metadata comment="page-sha256:$SHA" -movflags +faststart $WORK/walkthrough-720.mp4
step "Making the poster, the frame at $POSTER_AT s"
$ENV/bin/python -c "import sys; from PIL import Image; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2], 'WEBP', quality=88, method=6)" \
  $FRAMES/f$(printf %05d $(( ${POSTER_AT%.*} * 30 ))).png $WORK/poster.webp

for film in walkthrough walkthrough-720; do
  LONG=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $WORK/$film.mp4)
  awk -v d=$LONG -v want=$SECONDS_LONG 'BEGIN { exit !(d - want <= 0.1 && want - d <= 0.1) }' || fail "$film lasts $LONG s, not $SECONDS_LONG: nothing is replaced."
done

step "Putting them in $FILM"
cp $WORK/walkthrough.mp4 $WORK/walkthrough-720.mp4 $WORK/poster.webp $FILM/
print "✓ The film is drawn from today's page. Raise the ?v= of the film and poster in site/index.html."
