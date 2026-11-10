#!/bin/zsh
# The film's stills, for the owner's look before it is rendered (F002 AC-2, AC-5): one picture at
# every moment a tick, card, ring or mark of the page is fully there, with the moment's word, on a
# few contact sheets beside each other.
#
#   scripts/film/stills.sh        → ~/Library/Caches/causabee-film/stills/sheet-1.jpg …
set -e -u -o pipefail
cd "$(dirname "$0")/../.."
OUT=${CAUSABEE_FILM_DIR:-$HOME/Library/Caches/causabee-film}/stills
rm -rf $OUT; mkdir -p $OUT/t
ENV=.build-app/site-env
# Each moment of the page, a little after it begins, when what it brings is in place; the same moment once.
TIMES=($($ENV/bin/python - <<'EOF'
import json, re
page = open('site/film/walkthrough/index.html').read()
timing = json.load(open('site/film/walkthrough/timing.json'))
def at(m):
    l, w, end, off = re.fullmatch(r'(\d+)(?:\.(\d+))?(>)?([+-][\d.]+)?', m).groups()
    line = timing['lines'][int(l) - 1]
    t = line['words'][int(w) - 1][1 if end else 0] if w else (line['end'] if end else line['start'])
    return t + float(off or 0)
s0 = page.index('<div class="stage"'); body = page[s0:page.index('<script id="timing"', s0)]
times = sorted({round(at(m) + 0.7, 1) for m in re.findall(r'\{([^}]+)\}', body)})
picked = []
for t in times:
    if not picked or t - picked[-1] >= 0.9: picked.append(t)
print(' '.join(f'{t:.1f}' for t in picked if t < timing['total']))
EOF
))
print "→ ${#TIMES} stills"
swift scripts/film/render.swift site/film/walkthrough/index.html $OUT/t --at $TIMES --size 1920x1080 --ms --root site --query render | tail -1
$ENV/bin/python - $OUT <<'EOF'
import json, pathlib, sys
from PIL import Image, ImageDraw, ImageFont
out = pathlib.Path(sys.argv[1]); timing = json.load(open('site/film/walkthrough/timing.json'))
def said(t):
    for l in timing['lines']:
        if l['start'] - 0.5 <= t <= l['end'] + 1.2: return l['text']
    return ''
stills = sorted(out.glob('t/t*.png'), key=lambda p: float(p.stem[1:]))
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)
W, H, per = 640, 360, 12
for k in range(0, len(stills), per):
    sheet = Image.new('RGB', (3 * W + 40, 4 * (H + 60) + 20), 'white'); d = ImageDraw.Draw(sheet)
    for i, p in enumerate(stills[k:k + per]):
        x, y = 10 + (i % 3) * (W + 10), 10 + (i // 3) * (H + 60)
        sheet.paste(Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS), (x, y))
        d.text((x, y + H + 6), f"{float(p.stem[1:]):.1f} s · {said(float(p.stem[1:]))[:70]}", fill=(40, 40, 40), font=font)
    sheet.save(out / f'sheet-{k // per + 1}.jpg', quality=85)
print(f"{len(stills)} stills on {-(-len(stills) // per)} sheets → {out}")
EOF
