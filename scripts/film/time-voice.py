#!/usr/bin/env python3
"""The film's timing, from its reading: each line of voiceover.txt where the voice says it.

    python3 scripts/film/time-voice.py <reading.mp3> <reading-words.json>

The reading is the whole text in one take, as ElevenLabs read it (concept/film/walkthrough-voiceover-tags.txt;
the voice and model are in timing.json). It is never cut, stitched, sped up or shifted: the film is
timed to it, not it to the film. The words file is the connector's transcript of the reading, with
each word's time. Writes site/film/walkthrough/voice.mp3 (the reading, unchanged) and timing.json:
each line's start and end, and the film's length — the reading and the end card's last seconds.
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
    timed.append({"text": line, "start": round(spoken[at]["start"], 3), "end": round(spoken[at + len(want) - 1]["end"], 3)})
    at += len(want)
if at != len(spoken):
    sys.exit(f"The reading says {len(spoken) - at} words more than voiceover.txt")

length = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(reading)],
                              capture_output=True, text=True, check=True).stdout)
total = round(max(length, timed[-1]["end"]) + END_CARD, 1)
shutil.copyfile(reading, FILM / "voice.mp3")
(FILM / "timing.json").write_text(json.dumps({"voice": VOICE, "model": MODEL, "total": total, "lines": timed}, indent=1) + "\n")
print(f"{len(timed)} lines, read as written; the film lasts {total} s → site/film/walkthrough/timing.json, voice.mp3")
