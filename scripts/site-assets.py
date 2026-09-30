#!/usr/bin/env python3
"""Makes the website's images, icon and font from the app's own resources.

    python3 scripts/site-assets.py

Reads App/Resources (the intro screenshots, the icon's layers, Source Serif 4) and writes
site/assets. Run it again when the intro screenshots change. Needs Pillow, fontTools with
brotli, and rsvg-convert (brew install librsvg).
"""
import pathlib
import shutil
import subprocess

from fontTools import subset
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
INTRO = ROOT / "App/Resources/Intro"
OUT = ROOT / "site/assets"
IMG = OUT / "img"

# The screenshots are 1800 × 1125: a 900-point window at 2x. Each crop is (left, top, right, bottom).
CROPS = {
    "matter-phone": ("intro-2", (915, 0, 1785, 967), 684),
    "tasks": ("intro-3", (900, 290, 1800, 815), None),
    "calendar": ("intro-3", (905, 760, 1535, 1125), None),
    "files": ("intro-4", (900, 105, 1800, 630), None),
    "sources": ("intro-5", (900, 690, 1800, 1125), None),
    "assistant": ("intro-5", (342, 80, 897, 781), None),
}
FULL = {"overview": "intro-1", "matter": "intro-2"}

# The icon as Icon Composer draws it: the bee's stripes and wings over the yellow, the wings
# half see-through. The layers are App/Resources/BeeStripesWings.icon/Assets, moved up 30 points.
BARS = [(1525, 0, 1151), (1241, 436, 1719), (1241, 872, 1719), (1436, 1308, 1329), (1729.5, 1744, 742), (1925.5, 2180, 350)]
WINGS = [
    "M840.879 830.165C919.099 742.266 1064.5 797.594 1064.5 915.257V1953.13C1064.83 1960.84 1065 1968.59 1065 1976.37C1065 1984.16 1064.83 1991.9 1064.5 1999.61V2052.87L1059.83 2050.87C1023.6 2309.69 801.309 2508.87 532.5 2508.87C238.408 2508.87 0 2270.46 0 1976.37C0 1829.33 59.598 1696.21 155.956 1599.85L840.879 830.165Z",
    "M3360.12 830.165C3281.9 742.267 3136.5 797.594 3136.5 915.257V1953.13C3136.17 1960.84 3136 1968.59 3136 1976.37C3136 1984.16 3136.17 1991.9 3136.5 1999.61V2052.87L3141.17 2050.87C3177.4 2309.69 3399.69 2508.87 3668.5 2508.87C3962.59 2508.87 4201 2270.46 4201 1976.37C4201 1829.33 4141.4 1696.21 4045.04 1599.85L3360.12 830.165Z",
]


def webp(image, name):
    image.save(IMG / f"{name}.webp", "WEBP", quality=88, method=6)


def screenshots():
    IMG.mkdir(parents=True, exist_ok=True)
    for name, source in FULL.items():
        image = Image.open(INTRO / f"{source}.png").convert("RGB")
        webp(image, f"{name}-1800")
        webp(image.resize((900, 563), Image.LANCZOS), f"{name}-900")
    for name, (source, box, width) in CROPS.items():
        image = Image.open(INTRO / f"{source}.png").convert("RGB").crop(box)
        if width:
            image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
        webp(image, name)
    # The picture a shared link shows: the overview, cut to 1.91 : 1.
    overview = Image.open(INTRO / "intro-1.png").convert("RGB")
    overview.crop((0, 0, 1800, 942)).resize((1200, 628), Image.LANCZOS).save(OUT / "og.png", optimize=True)


def icon():
    bars = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="264" rx="112"/>' for x, y, w in BARS)
    wings = "".join(f'<path d="{d}" fill-opacity="0.5"/>' for d in WINGS)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<defs><linearGradient id="honey" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FFE14D"/><stop offset="1" stop-color="#FFC700"/></linearGradient></defs>'
        '<rect width="1024" height="1024" rx="230" fill="url(#honey)"/>'
        f'<g transform="translate(112 243.1) scale(0.190431)" fill="#000">{bars}{wings}</g></svg>\n'
    )
    (OUT / "icon.svg").write_text(svg)
    for size, name in [(180, "apple-touch-icon.png"), (32, "favicon-32.png")]:
        subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), str(OUT / "icon.svg"), "-o", str(OUT / name)], check=True)


def font():
    fonts = OUT / "fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    # Latin with the punctuation the pages use; both axes kept, so one file serves 400 and 600.
    subset.main([
        str(ROOT / "App/Resources/Fonts/SourceSerif4.ttf"),
        "--unicodes=U+0000-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212",
        "--layout-features=*",
        "--flavor=woff2",
        f"--output-file={fonts / 'SourceSerif4.woff2'}",
    ])
    shutil.copy(ROOT / "App/Resources/Fonts/SourceSerif4-LICENSE.md", fonts / "SourceSerif4-LICENSE.md")


if __name__ == "__main__":
    screenshots()
    icon()
    font()
    for path in sorted(OUT.rglob("*")):
        if path.is_file():
            print(f"{path.stat().st_size // 1024:6d} KB  {path.relative_to(ROOT)}")
