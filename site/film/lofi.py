"""The films' sound: instruments, effects and the master chain, shared by every film's soundtrack.py.

The instruments play a sunny, slightly wonky lo-fi groove: steel pan, a plucked bass, offbeat nylon
guitar, rimshot clave and shaker. A player plays them a little loose (play() in each soundtrack);
master() puts them in a small room, through an old 12-bit sampler, a tape machine and a dusty
record, so the music sounds sampled, not synthesized. Everything random is seeded: the same
soundtrack.py always makes the same sound.
"""
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, lfilter, resample_poly, sosfilt

SR = 48000
STEP = 60 / 100 / 4  # a sixteenth note at 100 BPM; a bar is 2.4 s
rng = np.random.default_rng(7)
hum = np.random.default_rng(11)  # the player: timing and touch


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
    x = x[: max(0, len(bus) - i)]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    bus[i:i + len(x), 0] += x * gain * l
    bus[i:i + len(x), 1] += x * gain * r


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


# --- master: a room, an old sampler, a tape machine and a dusty record --------------

def room(x, wet, size=0.7):
    """A small, warm room: decaying noise as the impulse response, different in each ear."""
    t = t_(size)
    ir = np.stack([lp(rng.standard_normal(len(t)), 4500) * np.exp(-t * 7) for _ in range(2)], 1)
    ir[: int(0.012 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2, 0))
    return x + wet * fftconvolve(x, ir, axes=0)[:len(x)]


def pump(x, kicks):
    """The loop ducks a little under each kick, as a chopped sample does."""
    N = len(x)
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
    return resample_poly(y, 2, 1, axis=0)[:len(x)] * peak


def tape(x):
    """Wow and flutter (the speed drifts), a warm bump in the bass, soft saturation, no sharp top."""
    N = len(x)
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



def master(music, sfx, kicks, length):
    """The finished mix: music in its room, sampled and pumping; effects in theirs; tape, record, fade."""
    N = len(music)
    music = sampler(pump(room(music, 0.22), kicks))
    out = tape(music + room(sfx, 0.12))
    out /= np.max(np.abs(out)) / 0.9
    out += record(N)
    out *= np.minimum(1, (length - np.arange(N) / SR) / 0.8)[:, None]
    out /= np.max(np.abs(out)) / 0.9
    return out


def write(path, out):
    wavfile.write(path, SR, (out * 32767).astype(np.int16))
