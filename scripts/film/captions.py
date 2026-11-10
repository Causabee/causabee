#!/usr/bin/env python3
"""The film's captions, from its timing: one caption per line of the voice, shown while she says it.

    python3 scripts/film/captions.py

Reads site/film/walkthrough/timing.json (written by time-voice.py) and writes walkthrough.vtt and
walkthrough.srt beside it. A long line is shown on two rows, broken at the comma, colon or dash
nearest its middle, as in October.
"""
import json, pathlib, re

FILM = pathlib.Path(__file__).resolve().parents[2] / "site/film/walkthrough"
WIDE = 46   # longer than this, a caption takes two rows


def rows(text):
    if len(text) <= WIDE: return [text]
    breaks = [m.end() for m in re.finditer(r"[,:;] |— |\. ", text)]
    if not breaks: return [text]
    at = min(breaks, key=lambda b: abs(b - len(text) / 2))
    return [text[:at].strip(), text[at:].strip()]


def stamp(seconds, comma):
    h, rest = divmod(round(seconds * 1000), 3_600_000)
    m, rest = divmod(rest, 60_000)
    s, ms = divmod(rest, 1000)
    return f"{h:02}:{m:02}:{s:02}{',' if comma else '.'}{ms:03}"


lines = json.loads((FILM / "timing.json").read_text())["lines"]
curly = lambda t: t.replace("'", "’")
vtt = ["WEBVTT", ""]
srt = []
for n, line in enumerate(lines, 1):
    text = "\n".join(rows(curly(line["text"])))
    vtt += [f"{stamp(line['start'], False)} --> {stamp(line['end'], False)}", text, ""]
    srt += [str(n), f"{stamp(line['start'], True)} --> {stamp(line['end'], True)}", text, ""]
(FILM / "walkthrough.vtt").write_text("\n".join(vtt))
(FILM / "walkthrough.srt").write_text("\n".join(srt))
print(f"{len(lines)} captions → walkthrough.vtt, walkthrough.srt")
