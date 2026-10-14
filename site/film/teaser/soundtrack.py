"""The teaser's music and sound effects, synthesized: python3 soundtrack.py out.wav [--devices]

With --devices it scores devices.html: 3.6 s more, for the iPhone and iPad scene at 10.8 s.

The music is a sunny, slightly wonky lo-fi groove: steel pan over a plucked bass, offbeat nylon
guitar, rimshot clave and shaker. It is played a little loose, in a small room, then put through
an old 12-bit sampler, a tape machine and a dusty record, so it sounds sampled, not synthesized.
100 BPM, so a bar is 2.4 s and the scenes change every 1.5 bars (3.6 s), on the beat.

Every effect time below matches an animation delay in index.html; change one, change the other.
"""
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, lfilter, resample_poly, sosfilt

SR = 48000
DEVICES = '--devices' in sys.argv
GAP = 3.6 if DEVICES else 0.0
LEN = 16.8 + GAP
N = int(SR * LEN)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
rng = np.random.default_rng(7)
hum = np.random.default_rng(11)  # the player: timing and touch
kicks = []
STEP = 60 / 100 / 4  # a sixteenth note


def T(t):
    """A time in the 16.8 s cut → the same moment in this one (later by GAP from the disguise on)."""
    return t + GAP if t >= 10.7 else t


def S(s):
    """The same for a sixteenth: the devices scene adds 24 of them at sixteenth 72 (10.8 s)."""
    return s + round(GAP / STEP) if s >= 72 else s


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def lp(x, hz, order=2):
    return sosfilt(butter(order, hz, 'low', fs=SR, output='sos'), x, axis=0)


def hp(x, hz, order=2):
    return sosfilt(butter(order, hz, 'high', fs=SR, output='sos'), x, axis=0)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x, axis=0)


def add(bus, x, at, gain=1.0, pan=0.0):
    """Mix mono x into a bus at `at` seconds; pan -1 left … 1 right."""
    i = int(at * SR)
    x = x[: max(0, N - i)]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    bus[i:i + len(x), 0] += x * gain * l
    bus[i:i + len(x), 1] += x * gain * r


def play(x, at, gain=1.0, pan=0.0):
    """Like add() to the music, but played by a person: a few ms early or late, never twice as hard."""
    add(music, x, max(0.0, at + hum.normal(0, 0.007)), gain * hum.uniform(0.82, 1.05), pan)


def hz(note):
    """'A4' → 440, 'F#5' → 740."""
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    n = names[note[0]] + (1 if '#' in note else 0)
    return 440 * 2 ** ((n + 12 * (int(note[-1]) - 4)) / 12)


def wobble(f, at, dur):
    """Tape wow and flutter: the pitch drifts the same way for every instrument at a moment."""
    t = at + t_(dur)
    return f * (1 + 0.002 * np.sin(2 * np.pi * 0.7 * t))  # the tape machine in the master adds the rest


def osc(f, at, dur, shape='sine'):
    ph = np.cumsum(wobble(f, at, dur)) / SR
    if shape == 'sine':
        return np.sin(2 * np.pi * ph)
    return np.sign(np.sin(2 * np.pi * ph))  # square


# --- instruments -----------------------------------------------------------------

def pan_note(f, at, dur=1.1):
    """Steel pan: a bright, slightly inharmonic ping with a soft bloom, and the mallet's tock."""
    f *= 2 ** (hum.normal(0, 4) / 1200)  # no two notes quite in tune
    t = t_(dur)
    x = (osc(f, at, dur) * np.exp(-t * 3.2)
         + 0.45 * osc(f * 2, at, dur) * np.exp(-t * 5)
         + 0.18 * osc(f * 3.02, at, dur) * np.exp(-t * 9))
    tock = bp(rng.standard_normal(len(t)), 1800, 6000) * np.exp(-t * 300)
    return x * np.minimum(1, t / 0.002) + 0.35 * tock


def pluck(f, dur, bright=0.5, damp=0.996):
    """A plucked string (Karplus–Strong): a burst of noise, ringing in a loop as long as one period."""
    L = max(2, int(round(SR / f - 0.5)))
    burst = lp(rng.uniform(-1, 1, L), 500 + 9000 * bright)
    x = np.zeros(int(SR * dur))
    x[:L] = burst
    a = np.zeros(L + 2)
    a[0], a[L], a[L + 1] = 1, -damp / 2, -damp / 2
    return lfilter([1], a, x)


def bass(f, at, dur):
    """A plucked bass string over a little sine for weight, muted by the hand after `dur`."""
    t = t_(dur + 0.04)
    x = lp(pluck(f, dur + 0.04, bright=0.06, damp=0.995), 1200) + 0.5 * osc(f, at, dur + 0.04) * np.exp(-t * 5)
    return x * np.minimum(1, (dur + 0.04 - t) / 0.04)


def guitar(notes, dur=0.2):
    """A nylon guitar, strummed down on the offbeat and damped by the palm."""
    x = np.zeros(int(SR * (dur + 0.05)))
    for k, n in enumerate(sorted(notes, key=hz)):
        i = int(SR * (k * 0.011 + hum.uniform(0, 0.003)))
        x[i:] += pluck(hz(n), dur + 0.05, bright=0.45)[: len(x) - i] * hum.uniform(0.7, 1)
    t = t_(dur + 0.05)
    return lp(x, 3500) * np.minimum(1, (dur + 0.05 - t) / 0.05) / len(notes)


def organ(notes, at, dur=0.13):
    """A short, round combo-organ stab on the offbeat."""
    t = t_(dur)
    x = sum(osc(hz(n), at, dur, 'square') + osc(hz(n) * 1.004, at, dur, 'square') for n in notes)
    return lp(x, 1800, 4) / (2 * len(notes)) * np.minimum(1, t / 0.004) * np.minimum(1, (dur - t) / 0.03)


def kick():
    t = t_(0.3)
    f = 48 + 70 * np.exp(-t * 35)
    beater = bp(rng.standard_normal(len(t)), 1000, 4000) * np.exp(-t * 250)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11) + 0.25 * beater


def rim():
    t = t_(0.08)
    wood = np.sin(2 * np.pi * 1750 * t) * np.exp(-t * 90) + 0.4 * np.sin(2 * np.pi * 520 * t) * np.exp(-t * 60)
    return wood + 0.6 * bp(rng.standard_normal(len(t)), 1500, 5000) * np.exp(-t * 120)


def shaker(accent):
    """Beads: a handful of tiny grains, not one burst of noise."""
    t = t_(0.09)
    x = np.zeros(len(t))
    for _ in range(14):
        i = int(abs(hum.normal(0.018, 0.012)) * SR)
        g = t_(0.004)
        x[i:i + len(g)] += (rng.standard_normal(len(g)) * np.exp(-g * 900))[: len(x) - i] * hum.uniform(0.3, 1)
    return bp(x, 4000, 11000) * (1 if accent else 0.55)


def clap():
    t = t_(0.15)
    n = bp(rng.standard_normal(len(t)), 900, 4000)
    env = sum(np.exp(-np.maximum(0, t - d) * 60) * (t >= d) for d in (0, 0.008, 0.017)) / 3
    return n * env


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

def pop(f, dur=0.12):
    t = t_(dur)
    sweep = f * (1 + np.exp(-t * 60))
    return np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-t * 35)


def swoosh(dur, lo, hi, shape=1.0):
    """A soft breath of air — kept low and narrow so it sits under the music."""
    t = t_(dur)
    x = lp(bp(rng.standard_normal(len(t)), lo, hi), hi * 0.8)
    return x * np.sin(np.pi * (t / dur) ** shape) ** 2


def stamp():
    t = t_(0.18)
    thump = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 32)
    click = hp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 140)
    return thump + 0.35 * click


def buzz(dur, base=210):
    """A bee's wingbeat: a buzzing saw, pulsing at ~28 Hz, with a slow wobble."""
    t = t_(dur)
    f = base * (1 + 0.03 * np.sin(2 * np.pi * 5 * t))
    ph = np.cumsum(f) / SR % 1
    x = lp(2 * ph - 1, 1400, 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t))
    return x * np.minimum(1, t / 0.05) * np.minimum(1, (dur - t) / 0.15)


def chime(dur=1.2):
    t = t_(dur)
    return sum(np.sin(2 * np.pi * hz(n) * t) * np.exp(-t * 3) for n in ('D6', 'A6', 'E7', 'F#7')) / 4 * np.minimum(1, t / 0.01)


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

# --- master: a room, an old sampler, a tape machine and a dusty record --------------

def room(x, wet, size=0.7):
    """A small, warm room: decaying noise as the impulse response, different in each ear."""
    t = t_(size)
    ir = np.stack([lp(rng.standard_normal(len(t)), 4500) * np.exp(-t * 7) for _ in range(2)], 1)
    ir[: int(0.012 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2, 0))
    return x + wet * fftconvolve(x, ir, axes=0)[:N]


def pump(x):
    """The loop ducks a little under each kick, as a chopped sample does."""
    g = np.ones(N)
    for k in kicks:
        i = int(k * SR)
        d = t_(0.25)[: N - i]
        g[i:i + len(d)] = np.minimum(g[i:i + len(d)], 1 - 0.22 * np.exp(-d * 14))
    return x * g[:, None]


def sampler(x, bits=12):
    """An old 12-bit sampler at 24 kHz: the top end goes soft and a fine grit comes in."""
    peak = np.max(np.abs(x))
    y = resample_poly(x / peak, 1, 2, axis=0)
    q = 2 ** (bits - 1)
    y = np.round(y * q + rng.uniform(-0.5, 0.5, y.shape)) / q
    return resample_poly(y, 2, 1, axis=0)[:N] * peak


def tape(x):
    """Wow and flutter (the speed drifts), a warm bump in the bass, soft saturation, no sharp top."""
    sec = np.arange(N) / SR
    drift = np.cumsum(rng.standard_normal(N // 4800 + 2)) * 0.00015
    drift = np.interp(sec, np.arange(len(drift)) * 0.1, drift)
    y = np.empty_like(x)
    for c in range(2):
        d = 0.0011 * np.sin(2 * np.pi * 0.55 * sec + c * 0.4) + 0.00012 * np.sin(2 * np.pi * 7.1 * sec) + drift
        y[:, c] = np.interp(sec - d, sec, x[:, c])
    y = y + 0.35 * lp(y, 110)
    y = np.tanh(1.7 * y + 0.06) - np.tanh(0.06)
    return lp(y, 11000)


def record(n):
    """A dusty record under everything: surface hiss, fine crackle and the odd pop."""
    surface = hp(lp(rng.standard_normal((n, 2)), 3500), 250) * 0.006
    crackle = np.zeros((n, 2))
    for rate, lo, hi in ((14, 0.01, 0.05), (0.7, 0.04, 0.1)):
        for _ in range(rng.poisson(rate * n / SR)):
            i, c = rng.integers(0, n - 200), rng.integers(0, 2)
            crackle[i:i + 200, c] += rng.uniform(lo, hi) * rng.choice([-1, 1]) * np.exp(-np.arange(200) / 25)
    return surface + hp(crackle, 900)


music = sampler(pump(room(music, 0.22)))
out = tape(music + room(sfx, 0.12))
out /= np.max(np.abs(out)) / 0.9
out += record(N)
out *= np.minimum(1, (LEN - np.arange(N) / SR) / 0.8)[:, None]
out /= np.max(np.abs(out)) / 0.9
wavfile.write(sys.argv[1], SR, (out * 32767).astype(np.int16))
