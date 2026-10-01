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
captions, web, site = "--captions" in sys.argv, "--web" in sys.argv, "--site" in sys.argv
web = web or site
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
                      ".stage { position: absolute; left: 0; top: 0; width: 1080px; height: 1920px; transform-origin: 0 0; }")
    src = src.replace("function seek(t) { for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; } }",
        """const TOTAL = %s;
function fit() { const s = Math.min(innerWidth / 1080, innerHeight / 1920); const st = document.querySelector('.stage'); st.style.transform = `scale(${s})`; st.style.left = ((innerWidth - 1080 * s) / 2) + 'px'; st.style.top = ((innerHeight - 1920 * s) / 2) + 'px'; }
addEventListener('resize', fit); fit();
function restart() { for (const a of document.getAnimations()) { a.cancel(); a.play(); } }
setInterval(restart, TOTAL * 1000 + 1500);
function seek(t) { for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; } }""" % t["total"])
    if site:
        # The website's copy: the site's own font file, and it only runs while it is on screen —
        # it starts from the beginning when scrolled into view, and rests when scrolled away.
        src = src.replace('src: url(assets/SourceSerif4.ttf);', 'src: url("../assets/fonts/SourceSerif4.woff2") format("woff2"); font-weight: 200 900;')
        src = src.replace("setInterval(restart, TOTAL * 1000 + 1500);", """let timer = null, shown = false;
function play() { restart(); clearInterval(timer); timer = setInterval(restart, TOTAL * 1000 + 1500); }
function rest() { clearInterval(timer); for (const a of document.getAnimations()) a.pause(); }
if (matchMedia('(prefers-reduced-motion: reduce)').matches) { seek(TOTAL - 2); }
else new IntersectionObserver(([e]) => { if (e.isIntersecting && !shown) { shown = true; play(); } else if (!e.isIntersecting && shown) { shown = false; rest(); } }, { threshold: 0.35 }).observe(document.body);""")
        # The voice, small enough for the web, and a speaker button in the lower right: off at first;
        # on, the voice is set to the film's clock (its animations' time) and kept within 0.15 s of it.
        (ROOT / "site/film").mkdir(exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(ROOT / f"docs/film/{t['voice']}-timed.mp3"), "-ac", "1", "-b:a", "64k", str(ROOT / "site/film/voice.mp3")], check=True)
        sound = """
<style>
.sound { position: fixed; right: 14px; bottom: 14px; width: 44px; height: 44px; border-radius: 50%; border: 0; padding: 0; display: grid; place-items: center; background: rgba(255,255,255,0.86); box-shadow: 0 2px 10px rgba(0,0,0,0.12), 0 0 0 1px rgba(0,0,0,0.06); color: #22211b; cursor: pointer; -webkit-backdrop-filter: blur(8px); backdrop-filter: blur(8px); z-index: 10; }
.sound svg { width: 22px; height: 22px; } .sound .on { display: none; } .sound[aria-pressed="true"] .on { display: block; } .sound[aria-pressed="true"] .off { display: none; }
.sound:focus-visible { outline: 2px solid #22211b; outline-offset: 2px; }
@media (prefers-reduced-motion: reduce) { .sound { display: none; } }
.clock { position: absolute; width: 0; height: 0; animation: clock-tick var(--end) linear both; }
@keyframes clock-tick { to { opacity: 1; } }
</style>
<div class="clock"></div>
<audio class="voice" src="voice.mp3" preload="none"></audio>
<button class="sound" type="button" aria-pressed="false" aria-label="Sound on">
  <svg class="off" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="m22 9-6 6M16 9l6 6"/></svg>
  <svg class="on" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>
</button>"""
        src = src.replace("</div>\n<script>", "</div>" + sound + "\n<script>")
        src = src.replace("function play() { restart(); clearInterval(timer); timer = setInterval(restart, TOTAL * 1000 + 1500); }",
"""const voice = document.querySelector('.voice'), button = document.querySelector('.sound');
let soundOn = false, onScreen = false;
// The film's clock: an invisible animation as long as the film, started and restarted with all the others.
function filmTime() { const a = document.querySelector('.clock').getAnimations()[0]; return a ? a.currentTime / 1000 : 0; }
function syncVoice() {
  if (!soundOn || !onScreen) { voice.pause(); return; }
  const t = filmTime();
  if (voice.paused) {
    // Started once, at the film's time; from then on the voice is never moved while it plays.
    if (isFinite(voice.duration) && t >= voice.duration) return;
    voice.currentTime = t; voice.play().catch(() => {});
    return;
  }
  // Drifted apart: the pictures follow the voice — silent and instant — instead of the voice jumping.
  const v = voice.currentTime;
  if (Math.abs(t - v) > 0.25) for (const a of document.getAnimations()) a.currentTime = v * 1000;
}
button.addEventListener('click', () => {
  soundOn = !soundOn;
  button.setAttribute('aria-pressed', soundOn); button.setAttribute('aria-label', soundOn ? 'Sound off' : 'Sound on');
  if (soundOn) { voice.preload = 'auto'; voice.load(); }
  syncVoice();
});
setInterval(syncVoice, 1000);
function play() { onScreen = true; restart(); voice.pause(); syncVoice(); clearInterval(timer); timer = setInterval(() => { restart(); voice.pause(); syncVoice(); }, TOTAL * 1000 + 1500); }""")
        src = src.replace("function rest() { clearInterval(timer); for (const a of document.getAnimations()) a.pause(); }",
                          "function rest() { onScreen = false; clearInterval(timer); for (const a of document.getAnimations()) a.pause(); voice.pause(); }")
        out = ROOT / "site/film/index.html"
        out.write_text(src); print("site", out); sys.exit(0)
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
