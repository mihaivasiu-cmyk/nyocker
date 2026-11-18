"""Builds the big-logo hero images at the top of some Discover pages, like Kerge's.

Each hero is the venue's own logo, large, on its page colour with a paper grain,
so it runs straight into the page below. Logos come from docs/logos (mirrored from
the venues' websites); small ones were traced to vectors in tools/heroes/ to stay sharp.
Run: python3 tools/make_heroes.py   (needs ImageMagick and rsvg-convert)
"""
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Nyocker" / "Assets.xcassets"
W, H = 900, 1000

# id: (page colour, logo file, largest logo width, largest logo height)
HEROES = {
    "hintalo": ("#16271E", "tools/heroes/hintalo.svg", 560, 520),
    "lumen": ("#EDEBE4", "tools/heroes/lumen.svg", 420, 600),
    "golya": ("#F2EEE6", "docs/logos/golya.png", 520, 600),
    "fecske": ("#200F01", "tools/heroes/fecske.svg", 600, 560),
    "grund": ("#121212", "tools/heroes/grund.svg", 680, 400),
}


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def build(key, colour, logo, max_w, max_h, work):
    source = ROOT / logo
    if source.suffix == ".svg":
        raster = work / f"{key}.png"
        run("rsvg-convert", "-w", "1800", "-o", raster, source)
        source = raster
    paper = work / f"{key}-paper.png"
    # Page colour with a soft, fixed grain, a touch lighter in the middle.
    run("convert", "-size", f"{W}x{H}", f"xc:{colour}",
        "(", "-size", f"{W}x{H}", "xc:gray50", "-seed", "8", "-attenuate", "0.9", "+noise", "Gaussian",
        "-colorspace", "gray", "-blur", "0x0.7", ")", "-compose", "softlight", "-composite",
        "(", "-size", f"{W}x{H}", "radial-gradient:white-black", "-evaluate", "multiply", "0.10", ")",
        "-compose", "screen", "-composite", "-type", "TrueColor", f"PNG24:{paper}")
    out_dir = ASSETS / f"{key}-hero.imageset"
    out_dir.mkdir(exist_ok=True)
    run("convert", f"PNG24:{paper}", "-colorspace", "sRGB", "(", source, "-trim", "+repage", "-resize", f"{max_w}x{max_h}", ")",
        "-gravity", "center", "-geometry", "+0-20", "-compose", "over", "-composite",
        "-colorspace", "sRGB", "-type", "TrueColor", "-strip", "-quality", "88", out_dir / f"{key}-hero.jpg")
    (out_dir / "Contents.json").write_text(
        '{"images":[{"filename":"%s-hero.jpg","idiom":"universal"}],"info":{"author":"xcode","version":1}}\n' % key)
    print("✓", key)


with tempfile.TemporaryDirectory() as tmp:
    for key, spec in HEROES.items():
        build(key, *spec, Path(tmp))
