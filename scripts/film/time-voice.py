#!/usr/bin/env python3
"""The film's timing, from its reading: each line of voiceover.txt where the voice says it.

    python3 scripts/film/time-voice.py <reading.mp3> <reading-words.json>

The reading is the whole text in one take, as ElevenLabs read it (concept/film/walkthrough-voiceover-tags.txt;
the voice and model are in timing.json). It is never cut, stitched, sped up or shifted: the film is
timed to it, not it to the film. The words file is the connector's transcript of the reading, with
each word's time. Writes site/film/walkthrough/voice.mp3 (the reading, unchanged) and timing.json:
each line's and each word's start and end, and the film's length (the reading and the end card's last seconds);
the same timing is written into index.html, where every moment of the picture is a word of the voice.
Refuses a reading that does not say the lines as written.
"""
import json, pathlib, re, shutil, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FILM = ROOT / "site/film/walkthrough"
VOICE, MODEL = "4rgssJ1pg3E9c0U78Iid", "eleven_v4"   # Carolyn - Warm Grounded Narrator (the owner, 10 November)
END_CARD = 2.5   # after "Be private.": the steel pan and the end card, as in October


def plain(text):
    return re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))


reading, words_file = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
lines = [l.strip() for l in (FILM / "voiceover.txt").read_text().splitlines() if l.strip()]
spoken = [w for w in json.loads(words_file.read_text())["words"]
          if w["type"] == "word" and plain(w["text"]) and not w["text"].startswith("[") and not w["text"].endswith("]")]

timed, at = [], 0
for k, line in enumerate(lines):
    want = plain(line)
    got = [" ".join(plain(w["text"])) for w in spoken[at: at + len(want)]]
    if got != want:
        sys.exit(f"Line {k + 1} is not read as written:\n  written: {' '.join(want)}\n  read:    {' '.join(got)}")
    said = spoken[at: at + len(want)]
    timed.append({"text": line, "start": round(said[0]["start"], 3), "end": round(said[-1]["end"], 3),
                  "words": [[round(w["start"], 3), round(w["end"], 3)] for w in said]})
    at += len(want)
if at != len(spoken):
    sys.exit(f"The reading says {len(spoken) - at} words more than voiceover.txt")

length = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(reading)],
                              capture_output=True, text=True, check=True).stdout)
total = round(max(length, timed[-1]["end"]) + END_CARD, 1)
shutil.copyfile(reading, FILM / "voice.mp3")
timing = {"voice": VOICE, "model": MODEL, "total": total, "lines": timed}
(FILM / "timing.json").write_text(json.dumps(timing, indent=1) + "\n")
# The page reads its moments from the same timing, written into it (so the film's fingerprint changes with it).
page = FILM / "index.html"
html = page.read_text()
block = f'<script id="timing" type="application/json">{json.dumps(timing, separators=(",", ":"))}</script>'
html, n = re.subn(r'<script id="timing" type="application/json">.*?</script>', lambda _: block, html, flags=re.S)
if n != 1: sys.exit("index.html has no <script id=\"timing\"> to write the timing into")
page.write_text(html)
print(f"{len(timed)} lines, read as written; the film lasts {total} s → site/film/walkthrough/timing.json, voice.mp3")
