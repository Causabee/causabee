#!/usr/bin/env python3
"""Builds the film: docs/film/timing.json → the page's timing variables → frames → MP4 with the voice.

    python3 scripts/film/build.py [seconds] [--captions] [--web]

  seconds     only the first seconds, to docs/film/film-preview.mp4
  --captions  the spoken line in a bar at the foot, to docs/film/film-captions.mp4
  --web       no render: writes scripts/film/web/film-web.html, which plays by itself, without
              audio, scaled to its container and looping — for the website
"""
import json, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
WEB = ROOT / "scripts/film/web"
args = [a for a in sys.argv[1:] if not a.startswith("--")]
captions, web = "--captions" in sys.argv, "--web" in sys.argv
t = json.load(open(ROOT / "docs/film/timing.json"))
LEAD = 0.5
vars_ = []
for b in t["beats"]:
    vars_.append(f"--b{b['beat']}: {b['start']}s; --v{b['beat']}: {b['start'] + LEAD}s; --s{b['beat']}: {b['spoken']}s;")
vars_.append(f"--end: {t['total']}s; --v19: {t['total']}s; --b19: {t['total']}s;")
src = (WEB / "film.src.html").read_text().replace("/*TIMING*/", " ".join(vars_))
if captions: src = src.replace("<body>", '<body class="captions">')
if web:
    # Plays on its own: no seek, the animations run from load; the stage scales into whatever holds it;
    # at the end the page restarts the animations, so it loops.
    src = src.replace("html, body { margin: 0; width: 1080px; height: 1920px; background: #fff; overflow: hidden;",
                      "html, body { margin: 0; width: 100%; height: 100%; background: #fff; overflow: hidden;")
    src = src.replace(".stage { position: relative; width: 1080px; height: 1920px; }",
                      ".stage { position: absolute; left: 50%; top: 50%; width: 1080px; height: 1920px; transform-origin: 0 0; }")
    src = src.replace("function seek(t) { for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; } }",
        """const TOTAL = %s;
function fit() { const s = Math.min(innerWidth / 1080, innerHeight / 1920); const st = document.querySelector('.stage'); st.style.transform = `translate(-50%%, -50%%) scale(${s})`; st.style.left = '50%%'; st.style.top = '50%%'; }
addEventListener('resize', fit); fit();
function restart() { for (const a of document.getAnimations()) { a.cancel(); a.play(); } }
setInterval(restart, TOTAL * 1000 + 1500);
function seek(t) { for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; } }""" % t["total"])
    out = WEB / ("film-web-captions.html" if captions else "film-web.html")
    out.write_text(src); print("web", out); sys.exit(0)
(WEB / "film.html").write_text(src)
seconds = float(args[0]) if args else t["total"]
frames = pathlib.Path("/tmp/film-clips/film-frames")
subprocess.run(["rm", "-rf", str(frames)])
subprocess.run(["swift", str(ROOT / "scripts/film/render.swift"), str(WEB / "film.html"), str(frames), str(seconds), "30"], check=True)
name = "film-preview.mp4" if args else ("film-captions.mp4" if captions else "film.mp4")
out = ROOT / "docs/film" / name
subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "30", "-i", str(frames / "f%05d.png"), "-i", str(ROOT / f"docs/film/{t['voice']}-timed.mp3"),
                "-vf", "scale=1080:1920:flags=lanczos,format=yuv420p", "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "160k", "-t", str(seconds), str(out)], check=True)
print("film", out, seconds, "s")
