#!/usr/bin/env python3
"""The film's reading, in October's tone: October's own voice for every line that is unchanged, and the
new lines read by the same voice on ElevenLabs, brought to October's pitch, pace and loudness.

    .build-app/site-env/bin/python scripts/film/splice-voice.py <take.mp3> [<take.mp3> …]

Each take holds the changed lines of voiceover.txt in order, a long pause (1.5 s) between them. For
each line the take closest to October is kept. Writes concept/film/reading.wav: every line of
voiceover.txt in order, 0.8 s apart, for time-voice.py to place; and concept/film/reading.json,
which line came from where.
"""
import json, os, pathlib, re, subprocess, sys
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
FILM = ROOT / "site/film/walkthrough"
SR, GAP = 44100, 0.8


def load(path, a=None, b=None):
    cut = ["-ss", f"{a}", "-to", f"{b}"] if a is not None else []
    raw = subprocess.run(["ffmpeg", "-v", "error", *cut, "-i", str(path), "-ar", str(SR), "-ac", "1", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(float)


def words(text):
    return re.findall(r"[A-Za-z0-9’']+", text)


def voiced(x):
    """The span that is spoken: from the first to the last 10 ms above -40 dB."""
    n = SR // 100
    frames = np.sqrt(np.mean(x[: len(x) // n * n].reshape(-1, n) ** 2, 1))
    on = np.where(frames > 10 ** (-40 / 20))[0]
    return x[on[0] * n: (on[-1] + 1) * n] if len(on) else x


def pitch(x):
    y = x[::3]; sr = SR / 3; n = int(sr * 0.04); rms = np.sqrt(np.mean(y ** 2)); f0 = []
    for i in range(0, len(y) - n, n // 4):
        fr = y[i:i + n]
        if np.sqrt(np.mean(fr ** 2)) < 0.3 * rms: continue
        fr = fr - fr.mean(); ac = np.correlate(fr, fr, "full")[n - 1:]
        lo, hi = int(sr / 400), int(sr / 90); k = lo + np.argmax(ac[lo:hi])
        if ac[k] > 0.5 * ac[0]: f0.append(sr / k)
    return float(np.median(f0))


def loud(x):
    return float(np.sqrt(np.mean(x ** 2)))


def segments(path):
    log = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", "silencedetect=noise=-35dB:d=1.3", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(s) for s in re.findall(r"silence_start: ([0-9.]+)", log)]
    ends = [float(s) for s in re.findall(r"silence_end: ([0-9.]+)", log)]
    return list(zip([0.0] + ends, starts + [None]))


def shift(x, semitones, tempo):
    """Higher by `semitones` and at `tempo` times the pace (asetrate, then atempo to set the pace)."""
    r = 2 ** (semitones / 12)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                          "-af", f"asetrate={SR * r:.0f},aresample={SR},atempo={tempo / r:.4f}", "-f", "f32le", "-"],
                         input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(float)


now = [l for l in (FILM / "voiceover.txt").read_text().splitlines() if l.strip()]
before = subprocess.run(["git", "-C", str(ROOT), "show", "main:site/film/walkthrough/voiceover.txt"], capture_output=True, text=True, check=True).stdout
flat = " ".join(before.replace("’", "'").split())
changed = [l for l in now if l not in flat]

# October's lines, from its captions (its voice is laid in film time).
vtt = subprocess.run(
    ["git", "-C", str(ROOT), "show", "main:site/film/walkthrough/walkthrough.vtt"], capture_output=True, text=True, check=True).stdout
cues = []
for m in re.finditer(r"(\d\d):(\d\d):([\d.]+) --> (\d\d):(\d\d):([\d.]+)\n((?:.+\n?)+)", vtt):
    t = [float(v) for v in m.groups()[:6]]
    cues.append((t[0] * 3600 + t[1] * 60 + t[2], t[3] * 3600 + t[4] * 60 + t[5], " ".join(m.group(7).split()).replace("’", "'")))
october = subprocess.run(["git", "-C", str(ROOT), "show", "main:site/film/walkthrough/voice.mp3"], capture_output=True, check=True).stdout
oct_path = ROOT / "concept/film/voice-october.mp3"; oct_path.write_bytes(october)


def october_line(line):
    """The cues that make up `line`, as one piece of October's voice."""
    for i in range(len(cues)):
        text = ""
        for j in range(i, len(cues)):
            text = (text + " " + cues[j][2]).strip()
            if text == line: return cues[i][0] - 0.12, cues[j][1] + 0.15
            if not line.startswith(text): break
    sys.exit(f"Not found in October's captions: {line}")


ref = [voiced(load(oct_path, *october_line(l))) for l in now if l not in changed]
want_pitch = float(np.median([pitch(x) for x in ref]))
want_pace = float(np.median([len(words(l)) / (len(x) / SR) for l, x in zip([l for l in now if l not in changed], ref)]))
want_loud = float(np.median([loud(x) for x in ref]))
print(f"October: {want_pitch:.0f} Hz, {want_pace:.2f} words/s")

takes = []
for path in sys.argv[1:]:
    segs = segments(path)
    if len(segs) != len(changed): sys.exit(f"{path}: {len(segs)} parts for {len(changed)} lines")
    takes.append([voiced(load(path, a, b if b is not None else 999)) for a, b in segs])

new, made = {}, {}
for k, line in enumerate(changed):
    def score(x):
        return abs(12 * np.log2(pitch(x) / want_pitch)) + 6 * abs(np.log(len(words(line)) / (len(x) / SR) / want_pace))
    best = min(range(len(takes)), key=lambda t: score(takes[t][k]))
    x = takes[best][k]
    # FILM_KEEP_PITCH=1: the pace and the loudness only; a shifted pitch moves the voice's colour with it.
    semis = 0.0 if os.environ.get("FILM_KEEP_PITCH") else float(np.clip(12 * np.log2(want_pitch / pitch(x)), -2, 2))
    tempo = float(np.clip(want_pace / (len(words(line)) / (len(x) / SR)), 0.8, 1.1))
    y = shift(x, semis, tempo)
    y *= want_loud / loud(y)
    new[line] = y
    made[line] = {"take": best + 1, "semitones": round(semis, 2), "tempo": round(tempo, 3),
                  "pitch": round(pitch(y)), "words_per_s": round(len(words(line)) / (len(y) / SR), 2)}
    print(f"  take {best + 1}, {semis:+.1f} st, pace ×{tempo:.2f} → {made[line]['pitch']} Hz, {made[line]['words_per_s']} w/s · {line[:50]}")

gap = np.zeros(int(SR * GAP)); parts, origin = [], []
for line in now:
    if line in new:
        parts.append(new[line]); origin.append({"line": line, "from": "new", **made[line]})
    else:
        x = voiced(load(oct_path, *october_line(line)))
        parts.append(x * want_loud / loud(x)); origin.append({"line": line, "from": "october"})
    parts.append(gap)
out = np.concatenate(parts); out /= max(1e-9, np.max(np.abs(out))) / 0.9
pcm = (out * 32767).astype(np.int16).tobytes()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", str(ROOT / "concept/film/reading.wav")], input=pcm, check=True)
(ROOT / "concept/film/reading.json").write_text(json.dumps({"october": {"pitch": round(want_pitch), "words_per_s": round(want_pace, 2)}, "lines": origin}, indent=1))
print(f"→ concept/film/reading.wav, {len(out) / SR:.1f} s")
