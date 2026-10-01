#!/usr/bin/env python3
"""Cuts an ElevenLabs reading of docs/film-voiceover.txt into its 18 lines and places each at its beat.

    python3 scripts/film/time-voice.py <voice.mp3> <name>

Finds the pauses, matches the phrases to the script's 29 parts (the [short pause] marks split a
line in two or three), and writes docs/film/<name>-timed.mp3, docs/film/timing.json and
docs/film-timing.md. A beat lasts its planned length, or the line plus some air, whichever is longer.
"""
import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
src, name = sys.argv[1], sys.argv[2]
WORDS = [4, 14, 6, 4, 23, 10, 2, 12, 6, 6, 8, 10, 5, 6, 9, 13, 13, 6]   # the script's 18 lines
PLANNED = [3, 5, 3, 3, 7, 5, 2, 4, 3, 3, 3, 4, 4, 4, 5, 5, 4, 4]   # 8–12 tightened: short lines, one object each
LEAD, TAIL, PAD_IN, PAD_OUT = 0.5, 1.0, 0.2, 0.7

def phrases(noise="-35dB", gap=0.25):
    log = subprocess.run(["ffmpeg", "-v", "info", "-i", src, "-af", f"silencedetect=noise={noise}:d={gap}", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(m) for m in re.findall(r"silence_start: ([0-9.]+)", log)]
    ends = [float(m) for m in re.findall(r"silence_end: ([0-9.]+)", log)]
    segs, cur = [], 0.0
    for s, e in zip(starts, ends + [None]):
        if s - cur > 0.3: segs.append((round(cur, 2), round(s, 2)))
        cur = e if e is not None else cur
    return segs

# Phrases to lines: a reading pauses inside lines too, so the phrases are grouped, in order, so that
# each line's span fits its length in words best (least squared error of the seconds-per-word rate).
segs = phrases()
n, m = len(segs), len(WORDS)
if n < m: sys.exit(f"Only {n} phrases found for {m} lines.")
spoken_total = sum(b - a for a, b in segs); rate = spoken_total / sum(WORDS)
INF = float("inf")
best = [[INF] * (n + 1) for _ in range(m + 1)]; cut = [[0] * (n + 1) for _ in range(m + 1)]
best[0][0] = 0.0
for i in range(1, m + 1):
    for j in range(i, n + 1):
        for k in range(i - 1, j):
            if best[i - 1][k] == INF: continue
            span = segs[j - 1][1] - segs[k][0]
            err = ((span - WORDS[i - 1] * rate) / (WORDS[i - 1] * rate)) ** 2
            if best[i - 1][k] + err < best[i][j]: best[i][j], cut[i][j] = best[i - 1][k] + err, k
lines, j = [], n
for i in range(m, 0, -1):
    k = cut[i][j]; lines.append((segs[k][0], segs[j - 1][1])); j = k
lines.reverse()
print(f"{n} phrases → 18 lines; words per second {1 / rate:.2f}")
beats, t = [], 0.0
for k, ((a, b), p) in enumerate(zip(lines, PLANNED)):
    spoken = b - a
    dur = max(p, round(spoken + LEAD + TAIL, 1))
    if k == len(lines) - 1: dur = spoken + LEAD + 2.5
    beats.append({"beat": k + 1, "start": round(t, 2), "dur": round(dur, 2), "voice_in": round(a, 2), "voice_out": round(b, 2), "spoken": round(spoken, 2)})
    t += dur
total = round(t, 1)
out = ROOT / f"docs/film/{name}-timed.mp3"
fc, mix = [], []
length = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src], capture_output=True, text=True).stdout)
for idx, bt in enumerate(beats):
    # Room before and after each line, so soft starts and tails are kept — but never into the neighbours.
    a = max(0, bt["voice_in"] - PAD_IN)
    if idx > 0: a = max(a, beats[idx - 1]["voice_out"] + 0.05)
    b = length if idx == len(beats) - 1 else min(bt["voice_out"] + PAD_OUT, beats[idx + 1]["voice_in"] - 0.05)
    ms = int((bt["start"] + LEAD) * 1000)
    fc.append(f"[0:a]atrim=start={a}:end={b},asetpts=PTS-STARTPTS,adelay={ms}|{ms}[l{bt['beat']}]"); mix.append(f"[l{bt['beat']}]")
fc.append("".join(mix) + f"amix=inputs={len(beats)}:normalize=0,apad=whole_dur={total}[out]")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-filter_complex", ";".join(fc), "-map", "[out]", "-c:a", "libmp3lame", "-q:a", "2", str(out)], check=True)
(ROOT / "docs/film/timing.json").write_text(json.dumps({"voice": name, "total": total, "beats": beats}, indent=1))
rows = "\n".join(f"| {b['beat']} | {b['start']:.1f} | {b['dur']:.1f} | {b['spoken']:.1f} | {b['voice_in']:.1f}–{b['voice_out']:.1f} |" for b in beats)
(ROOT / "docs/film-timing.md").write_text(f"""# The film's timing, from the voice

Voice: {name}, {length:.1f} s as generated. The lines are cut apart and placed again: each line
starts {LEAD} s into its beat, and a beat lasts its planned length or the line plus {LEAD + TAIL:.1f} s
of air, whichever is longer. The re-timed track is docs/film/{name}-timed.mp3 ({total} s); the
numbers are in docs/film/timing.json. Made by scripts/film/time-voice.py.

| Beat | Starts at (s) | Lasts (s) | Spoken (s) | In the original voice (s) |
| --- | --- | --- | --- | --- |
{rows}

Total: {total} s.
""")
print("total", total, "→", out)
