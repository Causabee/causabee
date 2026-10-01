#!/usr/bin/env python3
"""Builds the film: docs/film/timing.json → the page's timing variables → frames → MP4 with the voice.

    python3 scripts/film/build.py [seconds]       # the whole film, or only its first seconds
"""
import json, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
WEB = ROOT / "scripts/film/web"
t = json.load(open(ROOT / "docs/film/timing.json"))
LEAD = 0.5
vars_ = []
for b in t["beats"]:
    vars_.append(f"--b{b['beat']}: {b['start']}s; --v{b['beat']}: {b['start'] + LEAD}s; --s{b['beat']}: {b['spoken']}s;")
vars_.append(f"--end: {t['total']}s; --v19: {t['total']}s; --b19: {t['total']}s;")
src = (WEB / "film.src.html").read_text().replace("/*TIMING*/", " ".join(vars_))
(WEB / "film.html").write_text(src)
seconds = float(sys.argv[1]) if len(sys.argv) > 1 else t["total"]
frames = pathlib.Path("/tmp/film-clips/film-frames")
subprocess.run(["rm", "-rf", str(frames)])
subprocess.run(["swift", str(ROOT / "scripts/film/render.swift"), str(WEB / "film.html"), str(frames), str(seconds), "30"], check=True)
out = ROOT / ("docs/film/film.mp4" if len(sys.argv) == 1 else "docs/film/film-preview.mp4")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "30", "-i", str(frames / "f%05d.png"), "-i", str(ROOT / f"docs/film/{t['voice']}-timed.mp3"),
                "-vf", "scale=1080:1920:flags=lanczos,format=yuv420p", "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "160k", "-t", str(seconds), str(out)], check=True)
print("film", out, seconds, "s")
