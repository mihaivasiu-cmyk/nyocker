"""Mirrors each venue's logo (pipeline/logos.json) to docs/logos/<id>.png for the apps.

Logos come from the venue's own website. Each is converted to a PNG at most 512 px wide,
so the app gets one format whatever the site serves (PNG, JPEG, WebP or SVG).
Run: python3 pipeline/mirror_logos.py   (needs curl, ImageMagick and rsvg-convert)
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "logos"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"


def mirror(key: str, url: str, work: Path) -> None:
    raw = work / key
    subprocess.run(["curl", "-fsSL", "--max-time", "60", "-A", UA, "-o", str(raw), url], check=True)
    head = raw.read_bytes()[:512].lstrip()
    source = raw
    if url.lower().endswith(".svg") or head.startswith(b"<svg") or b"<svg" in head:
        source = work / f"{key}.svg.png"
        subprocess.run(["rsvg-convert", "-w", "1024", "-o", str(source), str(raw)], check=True)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["convert", str(source) + "[0]", "-trim", "+repage", "-resize", "512x512>",
                    "-strip", f"PNG32:{OUT / (key + '.png')}"], check=True)


def main() -> int:
    sources = json.loads((ROOT / "pipeline" / "logos.json").read_text(encoding="utf-8"))
    failed = []
    with tempfile.TemporaryDirectory() as tmp:
        for key, url in sorted(sources.items()):
            try:
                mirror(key, url, Path(tmp))
                print(f"✓ {key}")
            except subprocess.CalledProcessError as error:
                failed.append(key)
                print(f"✗ {key}: {error}", file=sys.stderr)
    for stale in OUT.glob("*.png"):
        if stale.stem not in sources:
            stale.unlink()
    print(f"{len(sources) - len(failed)} of {len(sources)} logos mirrored")
    return 1 if len(failed) == len(sources) else 0


if __name__ == "__main__":
    sys.exit(main())
