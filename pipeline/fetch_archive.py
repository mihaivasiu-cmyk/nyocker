"""Fetches the 33 archive photos (pipeline/archive_sources.json) into the app's asset catalog.

Each becomes Nyocker/Assets.xcassets/archive-<id>.imageset/archive-<id>.jpg, at most 1400 px
on its long side. Credits and stories live in Nyocker/content.json ("archive"), and the
picks are explained in pipeline/ARCHIVE.md. Fortepan photos are CC BY-SA 3.0; the
Wikimedia Commons ones carry the licence shown with each.

Run: python3 pipeline/fetch_archive.py [--if-missing]   (needs curl, and ImageMagick or macOS sips)
The TestFlight workflow runs it before building, so the photos never need committing.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Nyocker" / "Assets.xcassets"
UA = "NyockerArchive/1.0 (https://github.com/mihaivasiu-cmyk/nyocker)"


def main() -> int:
    only_missing = "--if-missing" in sys.argv
    sources = json.loads((ROOT / "pipeline" / "archive_sources.json").read_text(encoding="utf-8"))
    failed = []
    with tempfile.TemporaryDirectory() as tmp:
        for key, url in sources.items():
            folder = ASSETS / f"archive-{key}.imageset"
            target = folder / f"archive-{key}.jpg"
            if only_missing and target.exists():
                continue
            raw = Path(tmp) / key
            try:
                subprocess.run(["curl", "-fsSL", "--retry", "3", "--max-time", "90", "-A", UA, "-o", str(raw), url], check=True)
                folder.mkdir(exist_ok=True)
                if shutil.which("convert"):
                    subprocess.run(["convert", f"{raw}[0]", "-resize", "1400x1400>", "-strip", "-interlace", "Plane",
                                    "-quality", "82", str(target)], check=True)
                else:  # macOS runners have sips built in
                    subprocess.run(["sips", "-Z", "1400", "-s", "format", "jpeg", "-s", "formatOptions", "82",
                                    str(raw), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
                (folder / "Contents.json").write_text(
                    '{"images":[{"filename":"archive-%s.jpg","idiom":"universal"}],"info":{"author":"xcode","version":1}}\n' % key)
                print("✓", key)
            except subprocess.CalledProcessError as error:
                failed.append(key)
                print(f"✗ {key}: {error}", file=sys.stderr)
    print(f"{len(sources) - len(failed)} of {len(sources)} archive photos ready")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
