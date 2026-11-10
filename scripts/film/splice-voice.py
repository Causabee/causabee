#!/usr/bin/env python3
"""The film's reading, in October's own voice: October's reading for every line that is unchanged, and
the new lines as ElevenLabs read them — cut out, never sped up, slowed or shifted in pitch; only their
loudness is brought to October's.

    .build-app/site-env/bin/python scripts/film/splice-voice.py <take.mp3> <take-words.json>

The take holds the changed lines of voiceover.txt in order, read with eleven_v3 and the tags of
concept/film/walkthrough-voiceover-tags.txt ([long pause] between lines). The words file is the
connector's transcript of it, with each word's time; a line is cut from its first word to its last.
Writes concept/film/reading.wav — every line of voiceover.txt in order, 0.8 s apart, for
time-voice.py to place — and concept/film/reading.json, which line came from where.
"""
import json, pathlib, re, subprocess, sys
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
FILM = ROOT / "site/film/walkthrough"
SR, GAP, BEFORE, AFTER = 44100, 0.8, 0.12, 0.35


def git(*args, text=True):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=text, check=True).stdout


def load(path, a, b):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{max(0, a)}", "-to", f"{b}", "-i", str(path),
                          "-ar", str(SR), "-ac", "1", "-f", "f32le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(float)
    fade = int(SR * 0.03)  # no click at a cut
    x[:fade] *= np.linspace(0, 1, fade); x[-fade:] *= np.linspace(1, 0, fade)
    return x


def loud(x):
    """How loud it is while speaking: the RMS of the louder half of its 20 ms frames."""
    n = SR // 50
    frames = np.sqrt(np.mean(x[: len(x) // n * n].reshape(-1, n) ** 2, 1))
    return float(np.mean(np.sort(frames)[len(frames) // 2:]))


def plain(text):
    return " ".join(re.findall(r"[a-z0-9']+", text.lower().replace("’", "'")))


now = [l for l in (FILM / "voiceover.txt").read_text().splitlines() if l.strip()]
flat = " ".join(git("show", "main:site/film/walkthrough/voiceover.txt").replace("’", "'").split())
changed = [l for l in now if l not in flat]

# October's lines, from its captions: its voice is laid in film time.
cues = []
for m in re.finditer(r"(\d\d):(\d\d):([\d.]+) --> (\d\d):(\d\d):([\d.]+)\n((?:.+\n?)+)", git("show", "main:site/film/walkthrough/walkthrough.vtt")):
    t = [float(v) for v in m.groups()[:6]]
    cues.append((t[0] * 3600 + t[1] * 60 + t[2], t[3] * 3600 + t[4] * 60 + t[5], " ".join(m.group(7).split()).replace("’", "'")))
october = ROOT / "concept/film/voice-october.mp3"
october.write_bytes(git("show", "main:site/film/walkthrough/voice.mp3", text=False))


def october_line(line):
    for i in range(len(cues)):
        text = ""
        for j in range(i, len(cues)):
            text = (text + " " + cues[j][2]).strip()
            if text == line: return load(october, cues[i][0] - BEFORE, cues[j][1] + AFTER)
            if not line.startswith(text): break
    sys.exit(f"Not found in October's captions: {line}")


# The new lines, by their words' times: each line's words, in order, as the transcript has them.
take, words_file = sys.argv[1], sys.argv[2]
spoken = [w for w in json.loads(pathlib.Path(words_file).read_text())["words"]
          if w["type"] == "word" and plain(w["text"]) and not w["text"].startswith("[") and not w["text"].endswith("]")]
new, at = {}, 0
for k, line in enumerate(changed):
    want = plain(line).split()
    got = [plain(w["text"]) for w in spoken[at: at + len(want)]]
    if " ".join(got) != " ".join(want):
        sys.exit(f"The take does not say line {k + 1} as written:\n  wanted: {' '.join(want)}\n  heard:  {' '.join(got)}")
    first, last = spoken[at], spoken[at + len(want) - 1]
    after = spoken[at + len(want)]["start"] - 0.05 if at + len(want) < len(spoken) else last["end"] + AFTER
    new[line] = load(take, first["start"] - BEFORE, min(last["end"] + AFTER, after))
    at += len(want)
print(f"{len(changed)} new lines, word for word as written")

target = float(np.median([loud(october_line(l)) for l in now if l not in changed]))
gap = np.zeros(int(SR * GAP)); parts, origin = [], []
for line in now:
    x = new.get(line)
    x = october_line(line) if x is None else x
    parts += [x * target / loud(x), gap]
    origin.append({"line": line, "from": "new" if line in new else "october"})
out = np.concatenate(parts); out /= max(1e-9, np.max(np.abs(out))) / 0.9
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", str(ROOT / "concept/film/reading.wav")],
               input=(out * 32767).astype(np.int16).tobytes(), check=True)
(ROOT / "concept/film/reading.json").write_text(json.dumps({"take": take, "lines": origin}, indent=1))
print(f"→ concept/film/reading.wav, {len(out) / SR:.1f} s")
