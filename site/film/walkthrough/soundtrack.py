"""The walkthrough's sound: python3 soundtrack.py out.wav voice.wav

The voice leads: voice.wav (voice.mp3, decoded to 48 kHz) plays as it was read, from 0 s, and the
picture is timed to it. Under it, the music from ../lofi.py, kept small — the groove without its
melody, low, and lower still while she speaks — and the sounds of what is clicked and tapped. The
steel pan plays once, after "Be private", to bring the film home.

Every effect time below is when its thing happens in index.html; change one, change the other.
"""
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from lofi import *  # noqa: E402,F401,F403

LEN = 129.6
N = int(SR * LEN)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
kicks = []
END = 821  # the sixteenth the end card opens on (123.15 s)


def play(x, at, gain=1.0, pan=0.0):
    """Like add() to the music, but played by a person: a few ms early or late, never twice as hard."""
    add(music, x, max(0.0, at + hum.normal(0, 0.007)), gain * hum.uniform(0.82, 1.05), pan)


# --- the voice ---------------------------------------------------------------------
rate, v = wavfile.read(sys.argv[2])
assert rate == SR, 'voice.wav must be 48 kHz'
v = v.astype(float) / 32768
if v.ndim > 1:
    v = v.mean(1)
voice = np.zeros(N)
voice[:min(N, len(v))] = v[:N]
voice /= np.max(np.abs(voice)) / 0.9
# How much she is speaking, moment by moment (the lowpass gives it a soft release): the music makes room.
speaking = np.clip(lp(np.abs(voice), 4) / 0.05, 0, 1)

# --- music: the groove, round and round in D major, without a melody -----------------
loop = [
    ('D', ['D4', 'F#4', 'A4']), ('B', ['D4', 'F#4', 'B4']), ('G', ['D4', 'G4', 'B4']), ('A', ['C#4', 'E4', 'A4']),
    ('D', ['D4', 'F#4', 'A4']), ('F#', ['C#4', 'F#4', 'A4']), ('G', ['D4', 'G4', 'B4']), ('A', ['C#4', 'E4', 'G4']),
]
root_oct = {'D': 'D2', 'B': 'B1', 'G': 'G2', 'A': 'A2', 'F#': 'F#2', 'E': 'E2'}
for h in range(END // 8 + 1):
    root, triad = loop[h % len(loop)] if h * 8 < END else ('D', ['D4', 'F#4', 'A4'])
    t0 = h * 8 * STEP
    r = hz(root_oct[root])
    for s, mult, d in [(0, 1, 2.5), (3, 2, 1), (4, 1, 1.5), (6, 1.5, 1.5)]:
        if h * 8 == END and s:
            break
        play(bass(r * mult, t0 + s * STEP, d * STEP), t0 + s * STEP, 0.32)
    for s in (2, 6):
        if h * 8 < END:
            play(guitar(triad), t0 + s * STEP, 0.45, pan=0.35)
            play(organ(triad, t0 + s * STEP), t0 + s * STEP, 0.03, pan=0.5)

# The steel pan, once: home, after "Be private".
HOME = 846  # after "Be private" (126.9 s)
for s, n in [(0, 'D6'), (2, 'A5'), (3, 'F#5'), (4, 'A5'), (6, 'D6')]:
    at = (HOME + s) * STEP
    play(pan_note(hz(n), at, 2.4), at, 0.3, pan=-0.2)
    play(pan_note(hz(n), at + 3 * STEP, 2.4) * 0.3, at + 3 * STEP, 0.24, pan=0.45)

# Drums: shaker and clave all through; the kick and clap from the Mac on, not while the iPhone is asked.
clave = {0, 3, 6, 10, 12}
for s in range(END + 1):
    at = s * STEP
    play(shaker(s % 4 == 2), at, 0.08, pan=0.3)
    if s % 16 in clave:
        play(rim(), at, 0.1, pan=-0.3)
    asking = 481 <= s < 596 or 651 <= s < 725  # the letter scanned; the iPhone asked
    if s >= 120 and s % 8 == 0 and not asking:
        play(kick(), at, 0.45)
        kicks.append(at)
    if s >= 120 and s % 16 in (4, 12) and s < END and not asking:
        play(clap(), at, 0.06)
add(music, organ(['D4', 'F#4', 'A4', 'E5'], END * STEP, 3.0), END * STEP, 0.05)  # the end chord holds
add(music, guitar(['D4', 'F#4', 'A4', 'E5'], 3.0), END * STEP, 0.55, pan=0.2)

sec = np.arange(N) / SR
# The disguise sounds muffled, as if behind glass.
m = np.clip((sec - 24.65) / 0.25, 0, 1) * np.clip((39.25 - sec) / 0.15, 0, 1)
music = music * (1 - m[:, None]) + lp(music, 650, 4) * 1.15 * m[:, None]
# And the music steps back while she speaks.
music *= (1 - 0.55 * speaking)[:, None]

# --- sound effects -----------------------------------------------------------------

def tick(f='E6'):
    """A tap or a click: short and dry."""
    t = t_(0.05)
    return pop(hz(f), 0.05) + 0.3 * hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 200)


def check(at, pan):
    add(sfx, pop(hz('D6'), 0.1), at, 0.3, pan=pan)


def glad(at):
    """The bee is glad: a quick flutter and a little rising chirp."""
    add(sfx, buzz(0.9, base=300), at + 0.05, 0.08, pan=-0.1)
    for i, f in enumerate(['A5', 'D6', 'F#6']):
        add(sfx, pan_note(hz(f), at + 0.12 + i * 0.07, 0.35), at + 0.12 + i * 0.07, 0.09, pan=-0.1)


for i, (at, f) in enumerate([(1.75, 'D5'), (2.45, 'F#5'), (3.1, 'A5'), (3.85, 'B5'), (4.3, 'D6')]):
    add(sfx, pop(hz(f)), at + 0.22, 0.22, pan=[-0.5, 0.5, 0.05, 0.4, -0.35][i])  # each piece lands
add(sfx, swoosh(0.6, 300, 1600, shape=1.6), 5.9, 0.05)       # the pieces gather
add(sfx, pop(hz('D5'), 0.2), 6.5, 0.32)                     # into the bee
for at in (8.8, 9.1):
    add(sfx, swoosh(0.7, 200, 1400, shape=0.7), at, 0.03)    # the Mac and the iPad rise
add(sfx, pop(hz('F#5'), 0.18), 9.55, 0.2, pan=0.5)          # the iPhone slides in
for at, f, p in [(13.67, 'D5', 0), (14.54, 'F#5', -0.5), (15.51, 'A5', 0.5)]:
    add(sfx, pop(hz(f), 0.12), at, 0.14, pan=p)              # each nods as it is named
add(sfx, swoosh(0.5, 300, 1600), 17.9, 0.03)                # the Mac opens
add(sfx, pop(hz('A5'), 0.12), 19.55, 0.2, pan=-0.6)         # Auto is on
add(sfx, pop(hz('D6'), 0.12), 21.05, 0.26, pan=-0.4)        # 2 mails read
add(sfx, swoosh(0.5, 150, 800, shape=0.6), 24.6, 0.06)       # night wipes up
for at, p in zip([32.5, 34.75], [-0.3, 0.3]):
    add(sfx, stamp(), at, 0.3, pan=p)                        # names disguised
add(sfx, swoosh(0.5, 150, 800, shape=0.6), 38.96, 0.04)       # back to the Mac
add(sfx, tick('F#6'), 42.46, 0.25, pan=-0.3)                  # Take in
add(sfx, pop(hz('A5'), 0.15), 43.01, 0.28, pan=-0.4)        # taken in
add(sfx, pop(hz('D6'), 0.12), 46.31, 0.16)                  # the matter lights up
add(sfx, swoosh(0.5, 300, 1600), 48.16, 0.03)                # to the matter
for at, f in [(49.91, 'F#6'), (55.51, 'A6'), (58.11, 'B6')]:
    add(sfx, pop(hz(f), 0.1), at, 0.14)                      # what lights up
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), 59.86, 0.04)      # the iPad rises
add(sfx, pop(hz('F#5'), 0.18), 60.46, 0.28, pan=0.5)         # the iPhone slides in
add(sfx, pop(hz('D5'), 0.15), 62.71, 0.18)                  # the loupe
add(sfx, tick(), 63.86, 0.25, pan=-0.5)                       # first tick on the iPad
check(63.91, -0.5)
glad(64.06)
add(sfx, tick(), 65.16, 0.25, pan=-0.5)                       # second tick
check(65.21, -0.5)
glad(65.36)
for i, f in enumerate(['D6', 'F#6', 'A6', 'D7']):             # the tick flies over
    add(sfx, pan_note(hz(f), 68.86 + i * 0.2, 0.5), 68.86 + i * 0.2, 0.07, pan=-0.5 + i * 0.33)
check(69.61, 0.5)
add(sfx, buzz(1.85, base=200), 90.67, 0.045)                  # the bee comes with the pull
add(sfx, swoosh(0.4, 400, 1800), 92.52, 0.03)               # let go: it flies down
add(sfx, pop(hz('F#5'), 0.12), 92.9, 0.2)                  # into the mail's place
add(sfx, buzz(3.35, base=180), 92.92, 0.03)                  # at work
add(sfx, pop(hz('A5'), 0.15), 96.32, 0.28)                  # the card opens
add(sfx, pop(hz('D6'), 0.12), 96.57, 0.14)
add(sfx, tick(), 98.57, 0.25)                                 # the bee button
add(sfx, swoosh(0.5, 300, 1600), 98.72, 0.04)               # the assistant comes up
add(sfx, pop(hz('E6'), 0.12), 99.42, 0.24)                  # the question
for at, f in [(102.67, 'B5'), (103.22, 'D6'), (103.77, 'F#6')]:
    add(sfx, pan_note(hz(f), at, 0.4), at, 0.06)              # the answers
add(sfx, pop(hz('A5'), 0.12), 104.92, 0.16)                  # the suggestion
add(sfx, tick(), 107.27, 0.25)                                 # Add
add(sfx, pop(hz('A5'), 0.15), 107.42, 0.3)                   # taken in
add(sfx, swoosh(0.5, 300, 1600), 108.67, 0.03)                # back to the Mac
for at, f in [(112.72, 'F#6'), (113.32, 'G6'), (114.62, 'A6')]:
    add(sfx, pop(hz(f), 0.12), at, 0.18)                     # it's there, and there, and there
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), 116.5, 0.03)    # the Mac again
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), 119.0, 0.03)    # the iPad and the iPhone
add(sfx, pop(hz('F#5'), 0.18), 119.7, 0.22, pan=0.5)
add(sfx, chime(), 123.11, 0.18)                               # end card opens
add(sfx, pop(hz('A4'), 0.22), 123.31, 0.32)                  # icon pops
for i, f in enumerate(['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']):
    add(sfx, pan_note(hz(f), 123.91 + i * 0.08, 0.4), 123.91 + i * 0.08, 0.08, pan=-0.3 + i * 0.12)  # bars land
add(sfx, buzz(1.25, base=240), 123.71, 0.08)                  # wings flap twice

# The paper letter, scanned on the iPhone (72.2–89.4 s).
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), 72.6, 0.04)      # the letter is laid down
add(sfx, pop(hz('D6'), 0.12), 77.0, 0.16)                   # her own share lights up
add(sfx, pop(hz('F#5'), 0.18), 79.3, 0.26, pan=0.5)         # the iPhone comes
add(sfx, pop(hz('A5'), 0.1), 79.95, 0.14, pan=0.5)          # the page is found
t = t_(0.12)
add(sfx, hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 60), 80.95, 0.18, pan=0.5)  # the shutter
add(sfx, buzz(1.0, base=200), 81.45, 0.04, pan=0.5)          # read on the iPhone
add(sfx, pop(hz('D6'), 0.12), 82.5, 0.22, pan=0.5)          # 1 document read
add(sfx, pop(hz('F#6'), 0.1), 83.0, 0.14, pan=0.5)          # into Mum's matter
add(sfx, pop(hz('A6'), 0.1), 84.7, 0.14, pan=0.5)           # a task
add(sfx, tick(), 86.95, 0.25, pan=0.5)                       # Take in
add(sfx, pop(hz('A5'), 0.15), 87.05, 0.3, pan=0.5)          # taken in
# --- the mix: the bed small, the voice on top ----------------------------------------
bed = master(music, sfx, kicks, LEN)
out = 0.3 * bed + voice[:, None]
out /= np.max(np.abs(out)) / 0.9
write(sys.argv[1], out)
