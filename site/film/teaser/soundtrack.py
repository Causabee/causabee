"""The teaser's music and sound effects, synthesized: python3 soundtrack.py out.wav [--devices]

With --devices it scores devices.html: 3.6 s more, for the iPhone and iPad scene at 10.8 s.

The instruments and the sound come from ../lofi.py. 100 BPM, so a bar is 2.4 s and the scenes
change every 1.5 bars (3.6 s), on the beat.

Every effect time below matches an animation delay in index.html; change one, change the other.
"""
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from lofi import *  # noqa: E402,F401,F403

DEVICES = '--devices' in sys.argv
GAP = 3.6 if DEVICES else 0.0
LEN = 16.8 + GAP
N = int(SR * LEN)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
kicks = []


def T(t):
    """A time in the 16.8 s cut → the same moment in this one (later by GAP from the disguise on)."""
    return t + GAP if t >= 10.7 else t


def S(s):
    """The same for a sixteenth: the devices scene adds 24 of them at sixteenth 72 (10.8 s)."""
    return s + round(GAP / STEP) if s >= 72 else s


def play(x, at, gain=1.0, pan=0.0):
    """Like add() to the music, but played by a person: a few ms early or late, never twice as hard."""
    add(music, x, max(0.0, at + hum.normal(0, 0.007)), gain * hum.uniform(0.82, 1.05), pan)


# --- music -------------------------------------------------------------------------
# One chord per half bar (8 sixteenths, 1.2 s), in D major. Scenes change every 1.5 bars (3.6 s).
chords = [
    ('D', ['D4', 'F#4', 'A4']),    # 0.0   pieces
    ('B', ['D4', 'F#4', 'B4']),    # 1.2
    ('G', ['D4', 'G4', 'B4']),     # 2.4
    ('A', ['C#4', 'E4', 'A4']),    # 3.6   the bee and the overview
    ('D', ['D4', 'F#4', 'A4']),    # 4.8
    ('B', ['D4', 'F#4', 'B4']),    # 6.0
    ('G', ['D4', 'G4', 'B4']),     # 7.2   the matter
    ('A', ['C#4', 'E4', 'A4']),    # 8.4
    ('F#', ['C#4', 'F#4', 'A4']),  # 9.6
    *([('G', ['D4', 'G4', 'B4']), ('D', ['D4', 'F#4', 'A4']), ('A', ['C#4', 'E4', 'A4'])] if DEVICES else []),  # iPhone and iPad
    ('E', ['D4', 'G4', 'B4']),     # 10.8  the disguise (muffled)
    ('G', ['D4', 'G4', 'B4']),     # 12.0
    ('A', ['C#4', 'E4', 'G4']),    # 13.2
    ('D', ['D4', 'F#4', 'A4']),    # 14.4  end card: home
    ('D', ['D4', 'F#4', 'A4']),    # 15.6
]
root_oct = {'D': 'D2', 'B': 'B1', 'G': 'G2', 'A': 'A2', 'F#': 'F#2', 'E': 'E2'}
END = S(96)  # the sixteenth the end card opens on

for h, (root, triad) in enumerate(chords):
    t0 = h * 8 * STEP
    r = hz(root_oct[root])
    if h * 8 > END:  # after the end chord, only it rings
        break
    # Bass: a hopping calypso figure — root, octave up, fifth.
    for s, mult, d in [(0, 1, 2.5), (3, 2, 1), (4, 1, 1.5), (6, 1.5, 1.5)]:
        if h * 8 == END and s:
            break
        play(bass(r * mult, t0 + s * STEP, d * STEP), t0 + s * STEP, 0.36)
    # Guitar on the offbeats, a faint organ doubling it.
    for s in (2, 6):
        if h * 8 < END:
            play(guitar(triad), t0 + s * STEP, 0.55, pan=0.35)
            play(organ(triad, t0 + s * STEP), t0 + s * STEP, 0.05, pan=0.5)

# The melody, on the steel pan: one phrase a bar, (sixteenth in the bar, note).
phrases = [
    [(0, 'F#5'), (3, 'A5'), (6, 'B5'), (8, 'A5'), (10, 'F#5'), (12, 'E5'), (14, 'D5')],
    [(0, 'B4'), (2, 'D5'), (4, 'E5'), (7, 'F#5'), (10, 'E5'), (11, 'D5'), (13, 'B4')],
    [(0, 'F#5'), (2, 'A5'), (3, 'B5'), (6, 'D6'), (8, 'B5'), (11, 'A5'), (13, 'F#5')],
    [(0, 'B4'), (2, 'D5'), (4, 'E5'), (7, 'A5'), (10, 'G5'), (11, 'F#5'), (13, 'E5')],
    [(0, 'F#5'), (3, 'A5'), (6, 'C#6'), (8, 'B5'), (11, 'G5'), (14, 'E5')],
    [(0, 'G5'), (3, 'B5'), (6, 'A5'), (8, 'E5'), (11, 'G5'), (14, 'A5')],
    [(0, 'D6'), (2, 'A5'), (3, 'F#5'), (4, 'A5'), (6, 'D6')],
]
if DEVICES:  # a brighter phrase for the iPhone and iPad
    phrases_dev = [(72, 'D6'), (74, 'B5'), (75, 'A5'), (78, 'F#5'), (80, 'A5'), (82, 'B5'), (84, 'D6'),
                   (87, 'E6'), (90, 'D6'), (92, 'B5'), (94, 'A5')]
    for s, n in phrases_dev:
        play(pan_note(hz(n), s * STEP), s * STEP, 0.3, pan=-0.2)
        play(pan_note(hz(n), (s + 3) * STEP) * 0.3, (s + 3) * STEP, 0.24, pan=0.45)
for bar, phrase in enumerate(phrases):
    for s, n in phrase:
        s = S(s + bar * 16)
        at = s * STEP
        ring = 2.4 if s in (END, END + 6) else 1.1
        play(pan_note(hz(n), at, ring), at, 0.3, pan=-0.2)
        play(pan_note(hz(n), at + 3 * STEP, ring) * 0.3, at + 3 * STEP, 0.24, pan=0.45)  # a tape echo

# Drums: shaker and clave from the start, kick and clap once the bee arrives, one hit at the end.
clave = {0, 3, 6, 10, 12}
for s in range(END + 1):
    at = s * STEP
    play(shaker(s % 4 == 2), at, 0.1, pan=0.3)
    if s % 16 in clave:
        play(rim(), at, 0.12, pan=-0.3)
    if s >= 24 and s % 8 == 0:
        play(kick(), at, 0.6)
        kicks.append(at)
    if s >= 24 and s % 16 in (4, 12) and s < END:
        play(clap(), at, 0.09)
add(music, organ(['D4', 'F#4', 'A4', 'E5'], END * STEP, 2.2), END * STEP, 0.06)  # the end chord holds
add(music, guitar(['D4', 'F#4', 'A4', 'E5'], 2.2), END * STEP, 0.6, pan=0.2)

# The disguise scene sounds muffled, as if behind glass; it opens again on the end card.
sec = np.arange(N) / SR
m = np.clip((sec - T(10.7)) / 0.25, 0, 1) * np.clip((T(14.4) - sec) / 0.08, 0, 1)
music = music * (1 - m[:, None]) + lp(music, 650, 4) * 1.15 * m[:, None]

# --- sound effects -----------------------------------------------------------------

def sfx_at(x, at, *args, **kw):
    add(sfx, x, T(at), *args, **kw)


for d, p, f in zip([0.3, 0.6, 0.9, 1.2, 1.5], [-0.5, 0.5, -0.35, 0.4, 0.05], ['A5', 'D6', 'B5', 'E6', 'F#6']):
    sfx_at(pop(hz(f)), d + 0.22, 0.3, pan=p)         # each piece lands
sfx_at(swoosh(0.6, 300, 1600, shape=1.6), 2.9, 0.07)  # pieces gather in
sfx_at(pop(hz('D5'), 0.2), 3.4, 0.42)                 # bee pops
sfx_at(buzz(0.55), 3.45, 0.09, pan=-0.1)
for i, f in enumerate(['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']):
    sfx_at(pop(hz(f), 0.06), 3.55 + i * 0.05, 0.09)
sfx_at(swoosh(0.7, 200, 1400, shape=0.7), 4.1, 0.06)  # overview rises
for at, f in zip([7.65, 8.45, 9.25], ['D6', 'F#6', 'A6']):
    sfx_at(pop(hz(f), 0.15), at, 0.36)                 # the three pills
sfx_at(swoosh(0.5, 150, 800, shape=0.6), 10.7, 0.08)    # night wipes up
for at, p in zip([11.9, 12.2, 12.5], [-0.35, 0, 0.35]):
    sfx_at(stamp(), at, 0.35, pan=p)                   # names disguised
sfx_at(chime(), 14.4, 0.22)                             # end card opens
sfx_at(pop(hz('A4'), 0.22), 14.5, 0.4)                  # icon pops
for i, f in enumerate(['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']):
    sfx_at(pan_note(hz(f), 14.9 + i * 0.08, 0.4), 14.9 + i * 0.08, 0.1, pan=-0.3 + i * 0.12)  # bars land
sfx_at(buzz(1.25, base=240), 14.68, 0.1)                # wings flap twice

if DEVICES:
    add(sfx, swoosh(0.7, 200, 1400, shape=0.7), 10.85, 0.06)  # iPad rises
    add(sfx, pop(hz('F#5'), 0.18), 11.35, 0.36, pan=0.4)      # iPhone slides in
    add(sfx, pop(hz('A6'), 0.08), 12.6, 0.2, pan=0.4)         # its screen turns to the assistant

write(sys.argv[1], master(music, sfx, kicks, LEN))
