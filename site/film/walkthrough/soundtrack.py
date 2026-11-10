"""The walkthrough's sound: python3 soundtrack.py out.wav voice.wav

The voice leads: voice.wav (voice.mp3, decoded to 48 kHz) plays as it was read, from 0 s, and the
picture is timed to it. Under it, the music from ../lofi.py, kept small — the groove without its
melody, low, and lower still while she speaks — and the sounds of what is clicked and tapped. The
steel pan plays once, after "Be private", to bring the film home.

Every effect is a word of the voice, as every moment of index.html is: when('16.12') is when the
twelfth word of line 16 is said, from timing.json. The page and the sound read the same timing.
"""
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from lofi import *  # noqa: E402,F401,F403

import json  # noqa: E402
TIMING = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'timing.json')))


def when(m):
    """When a word of the voice is said: '16.12' its 12th word of line 16, '16' the line, '16>' its end, ±s after."""
    import re
    l, w, end, off = re.fullmatch(r'(\d+)(?:\.(\d+))?(>)?([+-][\d.]+)?', m).groups()
    line = TIMING['lines'][int(l) - 1]
    t = line['words'][int(w) - 1][1 if end else 0] if w else (line['end'] if end else line['start'])
    return t + float(off or 0)


LEN = TIMING['total']
N = int(SR * LEN)
music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
kicks = []
END = round(when('22-0.3') / STEP)  # the sixteenth the end card opens on


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
HOME = round(when('22>') / STEP) + 1  # after "Be private"
for s, n in [(0, 'D6'), (2, 'A5'), (3, 'F#5'), (4, 'A5'), (6, 'D6')]:
    at = (HOME + s) * STEP
    play(pan_note(hz(n), at, 2.4), at, 0.3, pan=-0.2)
    play(pan_note(hz(n), at + 3 * STEP, 2.4) * 0.3, at + 3 * STEP, 0.24, pan=0.45)

# Drums: shaker and clave all through; the kick and clap from the Mac on, not while the iPhone is asked.
clave = {0, 3, 6, 10, 12}
at_s = lambda s: s * STEP
for s in range(END + 1):
    at = s * STEP
    play(shaker(s % 4 == 2), at, 0.08, pan=0.3)
    if s % 16 in clave:
        play(rim(), at, 0.1, pan=-0.3)
    asking = when('16-0.4') <= at_s(s) < when('17-0.4') or when('18-0.4') <= at_s(s) < when('20-0.4')  # the letter scanned; the iPhone asked
    if at_s(s) >= when('4-0.4') and s % 8 == 0 and not asking:
        play(kick(), at, 0.45)
        kicks.append(at)
    if at_s(s) >= when('4-0.4') and s % 16 in (4, 12) and s < END and not asking:
        play(clap(), at, 0.06)
add(music, organ(['D4', 'F#4', 'A4', 'E5'], END * STEP, 3.0), END * STEP, 0.05)  # the end chord holds
add(music, guitar(['D4', 'F#4', 'A4', 'E5'], 3.0), END * STEP, 0.55, pan=0.2)

sec = np.arange(N) / SR
# The disguise sounds muffled, as if behind glass.
m = np.clip((sec - when('6-0.35')) / 0.25, 0, 1) * np.clip((when('8>+0.6') - sec) / 0.15, 0, 1)
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


A = when  # the effects below, each on the word the page has it on
for i, (w, f) in enumerate([('2.1', 'D5'), ('2.2', 'F#5'), ('2.3', 'A5'), ('2.4', 'B5'), ('2.5', 'D6')]):
    add(sfx, pop(hz(f)), A(w) + 0.12, 0.22, pan=[-0.5, 0.5, 0.05, 0.4, -0.35][i])   # each piece lands
add(sfx, swoosh(0.6, 300, 1600, shape=1.6), A('2.10-0.3'), 0.05)                    # the pieces gather
add(sfx, pop(hz('D5'), 0.2), A('2.10+0.1'), 0.32)                                   # into the bee
for w in ('3+0.2', '3+0.5'):
    add(sfx, swoosh(0.7, 200, 1400, shape=0.7), A(w), 0.03)                          # the Mac and the iPad rise
add(sfx, pop(hz('F#5'), 0.18), A('3+0.95'), 0.2, pan=0.5)                           # the iPhone slides in
for w, f, p in [('3.16', 'D5', 0), ('3.18', 'F#5', -0.5), ('3.21', 'A5', 0.5)]:
    add(sfx, pop(hz(f), 0.12), A(w), 0.14, pan=p)                                    # each nods as it is named
add(sfx, swoosh(0.5, 300, 1600), A('4+0.2'), 0.03)                                  # the Mac opens
add(sfx, pop(hz('D6'), 0.12), A('5.11'), 0.26, pan=-0.4)                            # what is new, on top
add(sfx, swoosh(0.5, 150, 800, shape=0.6), A('6-0.3'), 0.06)                         # night wipes up
for w, p in zip(['7.4', '7.9'], [-0.3, 0.3]):
    add(sfx, stamp(), A(w), 0.3, pan=p)                                              # names disguised
add(sfx, swoosh(0.5, 150, 800, shape=0.6), A('8>+0.3'), 0.04)                        # back to the Mac
add(sfx, pop(hz('A5'), 0.12), A('9.9'), 0.16)                                       # what is new
add(sfx, pop(hz('D6'), 0.12), A('9.13'), 0.16)                                      # what it brings
add(sfx, tick('F#6'), A('10.8'), 0.25, pan=0.3)                                    # the thumb takes the suggestion
add(sfx, swoosh(0.6, 500, 2200, shape=1.4), A('10.8+0.45'), 0.04)                    # it flies to the plan
add(sfx, pop(hz('A6'), 0.1), A('10.12'), 0.16)                                      # the Plan
add(sfx, swoosh(0.5, 300, 1600), A('11-0.4'), 0.03)                                  # to the next step
add(sfx, tick(), A('12.1'), 0.22)                                                    # the Plan, clicked
for w, f in [('11.5', 'F#6'), ('11.9', 'A6'), ('12.8', 'D6'), ('12.10', 'E6')]:
    add(sfx, pop(hz(f), 0.1), A(w), 0.14)                                            # what lights up
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), A('13-0.2'), 0.04)                       # the iPad rises
for w in ('13.10', '13.12'):
    add(sfx, tick(), A(w), 0.25, pan=-0.5)                                           # a tick on the iPad
    check(A(w) + 0.4, -0.5)
add(sfx, pop(hz('D5'), 0.15), A('13.10+0.2'), 0.18)                                 # the loupe
glad(A('13.12+0.4'))
add(sfx, pop(hz('F#5'), 0.18), A('14-0.1'), 0.28, pan=0.5)                          # the iPhone slides in
for i, f in enumerate(['D6', 'F#6', 'A6', 'D7']):                                  # the tick flies over
    add(sfx, pan_note(hz(f), A('14.4') + i * 0.2, 0.5), A('14.4') + i * 0.2, 0.07, pan=-0.5 + i * 0.33)
check(A('14.6'), 0.5)
check(A('14.6+0.3'), 0.5)
# The paper letter, scanned on the iPhone.
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), A('15+0.2'), 0.04)                       # the letter is laid down
add(sfx, pop(hz('D6'), 0.12), A('15.10+0.3'), 0.16)                                 # her own share lights up
add(sfx, pop(hz('F#5'), 0.18), A('16-0.3'), 0.26, pan=0.5)                          # the iPhone comes
add(sfx, pop(hz('A5'), 0.1), A('16.3'), 0.14, pan=0.5)                              # the page is found
t = t_(0.12)
add(sfx, hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 60), A('16.5'), 0.18, pan=0.5)  # the shutter
add(sfx, swoosh(0.5, 300, 1600), A('16.6'), 0.03)                                    # "Add a document"
add(sfx, tick(), A('16.12'), 0.25, pan=0.5)                                          # Sort in
add(sfx, buzz(1.0, base=200), A('16.12+0.5'), 0.04, pan=0.5)                        # read on the iPhone
add(sfx, pop(hz('A5'), 0.15), A('16.16'), 0.28, pan=0.5)                            # sorted in
add(sfx, pop(hz('F#6'), 0.1), A('16.19'), 0.14, pan=0.5)                            # into Mum's matter
add(sfx, pop(hz('A6'), 0.1), A('16.24'), 0.14, pan=0.5)                             # a task
# The pull: the bee leaves its button, comes with the pull, works, and goes home.
add(sfx, buzz(0.9, base=220), A('17.4'), 0.04)                                       # out of its button
add(sfx, buzz(1.5, base=200), A('17.6'), 0.045)                                      # with the pull
add(sfx, swoosh(0.4, 400, 1800), A('17.9>'), 0.03)                                   # let go: it flies down
add(sfx, pop(hz('F#5'), 0.12), A('17.9>+0.35'), 0.2)                                 # into the mail's place
add(sfx, buzz(2.6, base=180), A('17.9>+0.4'), 0.03)                                  # at work
add(sfx, pop(hz('A5'), 0.15), A('17.20'), 0.28)                                     # sorted
add(sfx, pop(hz('D6'), 0.12), A('17.20+0.25'), 0.14)
add(sfx, buzz(0.9, base=240), A('17.20+0.3'), 0.04)                                  # home to its button
add(sfx, pop(hz('D6'), 0.1), A('17.20+1.2'), 0.14)                                   # and it settles
add(sfx, tick(), A('18.1'), 0.25)                                                    # the bee button
add(sfx, swoosh(0.5, 300, 1600), A('18.1+0.5'), 0.04)                                # the chat comes up
add(sfx, pop(hz('E6'), 0.12), A('18.4'), 0.24)                                      # the question
for w, f in [('19.1', 'B5'), ('19.3', 'D6'), ('19.5', 'F#6')]:
    add(sfx, pan_note(hz(f), A(w), 0.4), A(w), 0.06)                                 # the answers
add(sfx, pop(hz('A5'), 0.12), A('19.6+0.3'), 0.16)                                  # the suggestion
add(sfx, tick(), A('19.15'), 0.25)                                                   # Add
add(sfx, pop(hz('A5'), 0.15), A('19.16'), 0.3)                                      # taken in
add(sfx, swoosh(0.5, 300, 1600), A('20-0.4'), 0.03)                                  # back to the Mac
for w, f in [('20.13', 'F#6'), ('20.13+0.6', 'G6'), ('20.21', 'A6')]:
    add(sfx, pop(hz(f), 0.12), A(w), 0.18)                                           # it's there, and there, and there
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), A('21+0.2'), 0.03)                       # the Mac again
add(sfx, swoosh(0.7, 200, 1400, shape=0.7), A('21.9'), 0.03)                         # the iPad and the iPhone
add(sfx, pop(hz('F#5'), 0.18), A('21.9+0.4'), 0.22, pan=0.5)
add(sfx, chime(), A('22-0.3'), 0.18)                                                 # end card opens
add(sfx, pop(hz('A4'), 0.22), A('22'), 0.32)                                        # icon pops
for i, f in enumerate(['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']):
    add(sfx, pan_note(hz(f), A('22+0.6') + i * 0.08, 0.4), A('22+0.6') + i * 0.08, 0.08, pan=-0.3 + i * 0.12)  # bars land
add(sfx, buzz(1.25, base=240), A('22+0.4'), 0.08)                                    # wings flap twice
# --- the mix: the bed small, the voice on top ----------------------------------------
bed = master(music, sfx, kicks, LEN)
out = 0.3 * bed + voice[:, None]
out /= np.max(np.abs(out)) / 0.9
write(sys.argv[1], out)
