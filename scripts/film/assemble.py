import subprocess, pathlib, textwrap, re
ROOT = pathlib.Path(__file__).resolve().parents[2]
CLIPS = pathlib.Path("/tmp/film-clips"); OUT = CLIPS / "out"; OUT.mkdir(exist_ok=True)
FONT = str(ROOT / "App/Resources/Fonts/SourceSerif4.ttf")
svg = (ROOT / "site/assets/icon.svg").read_text()
yellow = "0xFFC700"

def cap(name, text, width=30):
    p = OUT / f"{name}.txt"; p.write_text("\n".join(textwrap.wrap(text, width))); return str(p)

def draw(textfile, y=1560, size=46, color="white", box=True):
    d = f"drawtext=fontfile={FONT}:textfile={textfile}:fontsize={size}:fontcolor={color}:x=(w-text_w)/2:y={y}:line_spacing=12"
    if box: d += ":box=1:boxcolor=black@0.55:boxborderw=26"
    return d

def run(args): subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)

def clip(name, src, crop, dur, caption, start=0):
    x, y, w, h = crop
    run(["-ss", str(start), "-i", str(CLIPS / f"{src}.mp4"), "-t", str(dur),
         "-vf", f"crop={w}:{h}:{x}:{y},scale=1080:1920:flags=lanczos,{draw(cap(name, caption))}",
         "-r", "30", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-an", str(OUT / f"{name}.mp4")])

PHONE = pathlib.Path("/tmp/film-clips/phone")
PHONE_CROP = "crop=1180:2098:0:330"

def phone(name, src, segments, caption):
    """iPhone screen recordings (1180 x 2556): the given (start, length) pieces, cropped to 9:16 below the status bar."""
    parts = []
    for i, (start, length) in enumerate(segments):
        part = OUT / f"{name}-{i}.mp4"
        run(["-ss", str(start), "-i", str(PHONE / f"{src}.mp4"), "-t", str(length), "-map", "0:v",
             "-vf", f"{PHONE_CROP},scale=1080:1920:flags=lanczos,{draw(cap(name, caption))}",
             "-r", "30", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-an", str(part)])
        parts.append(part)
    lst = OUT / f"{name}-list.txt"; lst.write_text("".join(f"file '{p}'\n" for p in parts))
    run(["-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(OUT / f"{name}.mp4")])

def card(name, title, caption, dur, bg="0x1c1c1c", ink="white", soft="0xdddddd"):
    t = OUT / f"{name}-title.txt"; t.write_text("\n".join(textwrap.wrap(title, 26)))
    run(["-f", "lavfi", "-i", f"color=c={bg}:s=1080x1920:d={dur}:r=30",
         "-vf", f"{draw(str(t), y=760, size=64, color=ink, box=False)},{draw(cap(name, caption), y=1000, size=44, color=soft, box=False)}",
         "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", str(OUT / f"{name}.mp4")])

# 1 · the bee: the icon, slowly growing, on its own yellow
subprocess.run(["rsvg-convert", "-w", "900", "-h", "900", str(ROOT / "site/assets/icon.svg"), "-o", str(OUT / "icon.png")], check=True)
run(["-loop", "1", "-i", str(OUT / "icon.png"), "-t", "4",
     "-vf", f"pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color={yellow},zoompan=z='1+0.04*in/120':d=120:s=1080x1920:fps=30,{draw(cap('s01', 'Every matter. In its place.'), y=1480, size=56, color='0x1c1c1c', box=False)}",
     "-r", "30", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", str(OUT / "s01.mp4")])

# the crops, in the clips' 2380 × 1412 pixels: x, y, width, height — each 9:16
SIDEBAR = (0, 512, 506, 900)
SIDEBAR_TALL = (0, 0, 794, 1412)
RIGHT = (1290, 0, 794, 1412)
RIGHT_TOP = (1300, 100, 600, 1067)
THREAD = (560, 120, 680, 1209)
CARDS = (560, 0, 794, 1412)
CARDS_AFTER = (770, 0, 794, 1412)

clip("s02", "s02-overview", CARDS, 6, "Mum's care: the doctor, the insurer, the care service, your sister.")
clip("s03", "s03-getmail", SIDEBAR, 6, "Nothing is sent until you click Sort in.")
card("s04", "What the AI sees", "Dr. Brandt has the bath seat prescription for Helga.  →  [Person A] has the bath seat prescription for [Person B]. Names, addresses and numbers are replaced on your Mac first.", 7)
clip("s05", "s05-sortin", SIDEBAR_TALL, 6, "Sorted into the matter it belongs to. Every answer shows what it cost.")
clip("s06", "s06-nextstep", RIGHT_TOP, 6, "One thing to do now, and why it can't wait.")
phone("s07a", "scan", [(0.5, 5)], "The same matter on your iPhone, out and about.")
clip("s07b", "s07-mac-tick", RIGHT_TOP, 4, "Tick it on the phone. The Mac at home knows.", start=1)
phone("s08", "scan", [(14.0, 3.5), (21.5, 2.0), (31.0, 4.0), (49.5, 4.5)], "Scan a letter, and it goes into the matter. The paper stays on your phone.")
phone("s09", "mail", [(0.0, 3.2)], "Move a mail to the Causabee folder. It finds the matter it belongs to.")
clip("s10", "s10-tasks", RIGHT, 8, "Tasks are yours, shared, or someone else's you're waiting for. Some can only start after another.")
clip("s11", "s11-source", THREAD, 6, "Each task and date links back to the mail it came from.")
clip("s12", "s12-dates", RIGHT, 6, "Add a date to Calendar with one click. Change it in either place, and the other follows.")
clip("s13", "s13-files-people", RIGHT, 5, "Files, shared documents and everyone involved, each with their role.")
clip("s14", "s14-ask", THREAD, 10, "Ask in your own words. The answer shows its sources, and a good suggestion becomes a task in one click.")
clip("s15", "s15-overview-after", CARDS_AFTER, 7, "The next step is always clear. On the Mac, and on your iPhone.", start=1.5)
card("s16", "Causabee", "Free and open source · for Mac and iPhone · causabee.app", 4, bg=yellow, ink="0x1c1c1c", soft="0x1c1c1c")

order = ["s01", "s02", "s03", "s04", "s05", "s06", "s07a", "s07b", "s08", "s09", "s10", "s11", "s12", "s13", "s14", "s15", "s16"]
(OUT / "list.txt").write_text("".join(f"file '{OUT / (n + '.mp4')}'\n" for n in order))
run(["-f", "concat", "-safe", "0", "-i", str(OUT / "list.txt"), "-c", "copy", str(ROOT / "concept/film/draft-mac.mp4")])
print("done")
