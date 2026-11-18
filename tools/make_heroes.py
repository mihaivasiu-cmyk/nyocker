"""Builds the hero at the top of every Discover page (Kerge's is hand-made).

Two kinds:
- logo: the venue's own logo, large, on its page colour with a paper grain. Logos come
  from docs/logos (mirrored from the venues' websites); small ones were traced to
  vectors in tools/heroes/ so they stay sharp.
- card: venues that publish no logo get a name card of ours in their page style:
  their name set large, with a frame or motif. It is not meant to imitate any real sign.
  Lore spots get arcade title cards, apart from Keleti, which stays plain.

Run: python3 tools/make_heroes.py   (needs ImageMagick, rsvg-convert, and Playwright with Chrome)
"""
import html
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Nyocker" / "Assets.xcassets"
W, H = 900, 1000
PAGES = json.loads((ROOT / "Nyocker" / "discover.json").read_text(encoding="utf-8"))

# id: (logo file, largest logo width, largest logo height)
LOGOS = {
    "hintalo": ("tools/heroes/hintalo.svg", 560, 520),
    "lumen": ("tools/heroes/lumen.svg", 420, 600),
    "kislumen": ("tools/heroes/kislumen.svg", 380, 540),
    "golya": ("docs/logos/golya.png", 520, 600),
    "fecske": ("tools/heroes/fecske.svg", 600, 560),
    "grund": ("tools/heroes/grund.svg", 680, 400),
    "kk": ("docs/logos/kk.png", 700, 320),
    "fofoto": ("docs/logos/fofoto.png", 660, 320),
    "isbn": ("tools/heroes/isbn.svg", 520, 520),
    "museum": ("tools/heroes/museum.svg", 700, 260),
    "apricot": ("tools/heroes/apricot.svg", 700, 260),
    "humana": ("docs/logos/humana.png", 700, 260),
    "szabo": ("tools/heroes/szabo.svg", 380, 600),
    "fuvesz": ("tools/heroes/fuvesz.svg", 640, 520),
}

# Category marks, the same shapes as the map pins (30 px grid).
GLYPHS = {
    "bar": '<path d="M9 9h12l-6 7z"/><rect x="14" y="15" width="2" height="5"/><rect x="11.5" y="19.5" width="7" height="2"/>',
    "club": '<rect x="9" y="12" width="3" height="6"/><rect x="13.5" y="9" width="3" height="12"/><rect x="18" y="11" width="3" height="8"/>',
    "art": '<rect x="9.5" y="9.5" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.6"/>',
    "eat": '<path d="M8 13h14a7 7 0 0 1-14 0z"/>',
    "thrift": '<path d="M15 10l7 9H8z" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linejoin="round"/><circle cx="15" cy="8" r="1.8"/>',
    "local": '<path d="M8 15l7-6 7 6v6H8z"/>',
}

# id: name, small line above, line below, font, decoration, category mark
CARDS = {
    "brody": ("Bródy", "BRÓDY SÁNDOR UTCA 2", "ITALINTÉZET", "Cardo:700", "label", "bar"),
    "susuka": ("susuka", "NAGY FUVAROS UTCA", "KOCSMA", "Poppins:700", "stamp", "bar"),
    "zsir": ("ZSÍR", "KISS JÓZSEF UTCA", "FŐVÁROSI KULIPINTYÓ", "Anton:400", "neon", None),
    "kraken": ("KRAK'N TOWN", "JÓZSEF KÖRÚT 31/A", "STEAMPUNK SALOON · ANNO 2316", "Cardo:700", "frame", "bar"),
    "kupsus": ("Ari Kupsus", "BRÓDY SÁNDOR UTCA 23/B", "GALÉRIA", "Crimson Text:italic 700", "picture", "art"),
    "cozy": ("cozy", "VAS UTCA", "STUDIO & CAFÉ", "Poppins:600", "stamp", "art"),
    "kazan": ("KAZÁN", "ORCZY ÚT 46-48", "KÖZÖSSÉGI HÁZ", "Anton:400", "stripes", "art"),
    "kv": ("kv", "VAS UTCA & KŐFARAGÓ UTCA", "THE COFFEE SHOP", "Inter:900", "plain", "eat"),
    "anton": ("Anton", "BRÓDY SÁNDOR UTCA 23/A", "COFFEE & BAKERY", "Lora:700", "label", "eat"),
    "csarnok": ("Vásárcsarnok", "RÁKÓCZI TÉR · 1897", "MARKET HALL", "Cardo:700", "arch", "eat"),
    "kiskina": ("KISKÍNA", "KŐBÁNYAI ÚT", "LITTLE CHINA", "Anton:400", "lanterns", "eat"),
    "prater": ("Práter", "PRÁTER UTCA 9", "VINTAGE SHOP", "Lora:italic 700", "frame", "thrift"),
    "konfekcio": ("KONFEKCIÓ", "JÓZSEF UTCA 16", "TRASH IS HIGH FASHION", "Anonymous Pro:700", "tape", "thrift"),
    "typo": ("Momoko", "KRÚDY GYULA UTCA", "VINTAGE · FORMERLY TYPO", "Poppins:700", "stamp", "thrift"),
    "gizmo": ("GIZMO", "SOMOGYI BÉLA UTCA", "VINTAGE", "Archivo Black:400", "offset", "thrift"),
    "teleki": ("Zsibi", "TELEKI TÉRI PIAC", "FLEA MARKET", "Poppins:700", "awning", "thrift"),
    "horvath": ("Horváth Mihály tér", "JÓZSEFVÁROS", "THE DISTRICT'S PARTY SQUARE", "Archivo Black:400", "stamp", "local"),
    "matyas": ("Mátyás tér", "MAGDOLNA NEGYED", "HEART OF THE QUARTER", "Poppins:700", "waves", "local"),
    "kerepesi": ("Fiumei úti sírkert", "FIUMEI ÚT 16-18", "NATIONAL GRAVEYARD", "Cardo:700", "frame", None),
}
LORE = ["sinkhole", "raid", "aurora", "tigris", "corvinrip", "blaha", "oldgolya", "grundkert"]


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def paper(colour, out):
    """The page colour with a soft, fixed grain, a touch lighter in the middle."""
    run("convert", "-size", f"{W}x{H}", f"xc:{colour}",
        "(", "-size", f"{W}x{H}", "xc:gray50", "-seed", "8", "-attenuate", "0.9", "+noise", "Gaussian",
        "-colorspace", "gray", "-blur", "0x0.7", ")", "-compose", "softlight", "-composite",
        "(", "-size", f"{W}x{H}", "radial-gradient:white-black", "-evaluate", "multiply", "0.10", ")",
        "-compose", "screen", "-composite", "-type", "TrueColor", f"PNG24:{out}")


def save(key, image):
    out_dir = ASSETS / f"{key}-hero.imageset"
    out_dir.mkdir(exist_ok=True)
    run("convert", image, "-colorspace", "sRGB", "-type", "TrueColor", "-strip", "-quality", "88",
        out_dir / f"{key}-hero.jpg")
    (out_dir / "Contents.json").write_text(
        '{"images":[{"filename":"%s-hero.jpg","idiom":"universal"}],"info":{"author":"xcode","version":1}}\n' % key)


def logo_hero(key, logo, max_w, max_h, work):
    source = ROOT / logo
    if source.suffix == ".svg":
        raster = work / f"{key}-logo.png"
        run("rsvg-convert", "-w", "1800", "-o", raster, source)
        source = raster
    base = work / f"{key}-paper.png"
    paper(PAGES[key]["colors"]["brick"], base)
    out = work / f"{key}.png"
    run("convert", f"PNG24:{base}", "-colorspace", "sRGB", "(", source, "-trim", "+repage", "-resize", f"{max_w}x{max_h}", ")",
        "-gravity", "center", "-geometry", "+0-20", "-compose", "over", "-composite", out)
    save(key, out)


def card_html(key):
    page = PAGES[key]
    c = page["colors"]
    text, gold, brick = c.get("text", c["paper"]), c["gold"], c["brick"]
    if key in LORE:
        name, top, sub, font, deco, glyph = page["title"], "★ DISTRICT LEGEND ★", page["subtitle"].upper(), "Unifont:400", "arcade", None
    elif key == "keleti":
        name, top, sub, font, deco, glyph = "Keleti", "BAROSS TÉR", page["subtitle"].upper(), "Lora:400", "quiet", None
    else:
        name, top, sub, font, deco, glyph = CARDS[key]
    family, _, weight = font.partition(":")
    italic = "italic" in weight
    weight = weight.replace("italic", "").strip() or "400"
    mark = ""
    if glyph:
        mark = (f'<svg class="mark" viewBox="0 0 30 30" aria-hidden="true"><circle cx="15" cy="15" r="15" fill="{gold}"/>'
                f'<g fill="{c["deep"]}" color="{c["deep"]}">{GLYPHS[glyph]}</g></svg>')
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:transparent}}
.hero{{position:relative;width:{W}px;height:{H}px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:26px;color:{text};text-align:center;box-sizing:border-box;padding:0 90px}}
.top{{font:700 22px/1 'Inter';letter-spacing:5px;opacity:.75}}
.name{{font-family:'{family}';font-weight:{weight};font-style:{'italic' if italic else 'normal'};font-size:190px;line-height:.95;white-space:nowrap}}
.sub{{font:800 24px/1.3 'Inter';letter-spacing:6px;color:{gold}}}
.mark{{width:120px;height:120px}}
.rule{{width:120px;height:3px;background:{gold}}}
.d-frame::before,.d-picture::before{{content:"";position:absolute;inset:56px;border:3px solid {text};opacity:.35}}
.d-frame::after{{content:"";position:absolute;inset:72px;border:1px solid {text};opacity:.25}}
.d-picture::after{{content:"";position:absolute;inset:44px;border:26px solid {gold};opacity:.85;box-shadow:inset 0 0 0 3px {text}}}
.d-label .plate{{border:4px solid {gold};border-radius:50%/42%;padding:60px 80px;display:flex;flex-direction:column;align-items:center;gap:22px;box-shadow:0 0 0 14px {brick},0 0 0 17px {text}55}}
.d-stamp .plate{{border:5px dashed {gold};border-radius:50%;width:560px;height:560px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;transform:rotate(-6deg)}}
.d-neon .name{{color:{gold};text-shadow:0 0 18px {gold},0 0 46px {gold}aa;font-size:300px}}
.d-stripes::before{{content:"";position:absolute;left:0;right:0;top:0;height:120px;background:repeating-linear-gradient(-45deg,{gold} 0 34px,transparent 34px 68px);opacity:.9}}
.d-stripes::after{{content:"";position:absolute;left:0;right:0;bottom:0;height:120px;background:repeating-linear-gradient(-45deg,{gold} 0 34px,transparent 34px 68px);opacity:.9}}
.d-awning::before{{content:"";position:absolute;left:0;right:0;top:0;height:170px;background:repeating-linear-gradient(90deg,{gold} 0 75px,{text} 75px 150px);clip-path:polygon(0 0,100% 0,100% 72%,95.8% 100%,91.6% 72%,87.5% 100%,83.3% 72%,79.1% 100%,75% 72%,70.8% 100%,66.6% 72%,62.5% 100%,58.3% 72%,54.1% 100%,50% 72%,45.8% 100%,41.6% 72%,37.5% 100%,33.3% 72%,29.1% 100%,25% 72%,20.8% 100%,16.6% 72%,12.5% 100%,8.3% 72%,4.1% 100%,0 72%)}}
.d-tape .name{{background:{gold};color:{c['deep']};padding:18px 34px;transform:rotate(-3deg);box-shadow:10px 10px 0 {text}}}
.d-offset .name{{text-shadow:12px 12px 0 {gold}}}
.d-arch::before{{content:"";position:absolute;left:110px;right:110px;top:110px;height:820px;border:6px solid {gold};border-bottom:0;border-radius:340px 340px 0 0;opacity:.7}}
.d-arch::after{{content:"";position:absolute;left:150px;right:150px;top:150px;height:780px;border:2px solid {text};border-bottom:0;border-radius:300px 300px 0 0;opacity:.3}}
.d-lanterns::before{{content:"";position:absolute;left:0;right:0;top:70px;height:110px;background:radial-gradient(circle at 50% 55%,{gold} 0 30px,transparent 31px) 0 0/150px 110px,linear-gradient({text}66,{text}66) 0 18px/100% 2px no-repeat}}
.d-waves::before{{content:"";position:absolute;inset:0;background:radial-gradient(circle at 50% 0,transparent 30px,{gold}55 31px 35px,transparent 36px) 0 0/110px 70px;opacity:.5}}
.d-arcade{{gap:30px}}
.d-arcade::before{{content:"";position:absolute;inset:48px;border:12px solid {gold};box-shadow:inset 0 0 0 12px {brick},inset 0 0 0 18px {text}}}
.d-arcade .name{{font-size:96px;line-height:1.1;white-space:normal;max-width:680px}}
.d-arcade .top{{font:400 32px/1 'Unifont';letter-spacing:4px;color:{gold};opacity:1}}
.d-arcade .sub{{font:400 40px/1 'Unifont';color:{text};letter-spacing:4px}}
.d-arcade .press{{font:400 28px/1 'Unifont';color:{gold};letter-spacing:3px}}
.d-quiet .name{{font-size:150px}}
.d-quiet .sub{{color:{text};opacity:.8;letter-spacing:5px}}
</style></head><body>
<div class="hero d-{deco}">
<div class="plate" style="display:contents">
{mark}
<div class="top">{html.escape(top)}</div>
<div class="name" id="name">{html.escape(name)}</div>
{'<div class="rule"></div>' if deco not in ("arcade", "neon") else ''}
<div class="sub">{html.escape(sub)}</div>
{'<div class="press">PRESS A TO READ</div>' if deco == "arcade" else ''}
</div></div>
<script>
const n=document.getElementById('name'), plated=['label','stamp'].includes('{deco}');
if(plated){{const p=document.querySelector('.plate');p.style.display='flex';}}
const room=plated?(('{deco}'==='stamp')?470:620):720;
let size=parseFloat(getComputedStyle(n).fontSize);
while(n.scrollWidth>room&&size>40){{size-=4;n.style.fontSize=size+'px';}}
document.fonts.ready.then(()=>{{let s=parseFloat(getComputedStyle(n).fontSize);while(n.scrollWidth>room&&s>40){{s-=4;n.style.fontSize=s+'px';}}document.body.dataset.ready=1;}});
</script></body></html>"""


def card_heroes(keys, work):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path="/usr/bin/google-chrome", args=["--no-sandbox"])
        tab = browser.new_page(viewport={"width": W, "height": H})
        for key in keys:
            page_file = work / f"{key}.html"
            page_file.write_text(card_html(key), encoding="utf-8")
            tab.goto(page_file.as_uri())
            tab.wait_for_selector("body[data-ready]")
            layer = work / f"{key}-layer.png"
            tab.screenshot(path=str(layer), omit_background=True)
            base = work / f"{key}-paper.png"
            paper(PAGES[key]["colors"]["brick"], base)
            out = work / f"{key}.png"
            run("convert", f"PNG24:{base}", "-colorspace", "sRGB", layer, "-compose", "over", "-composite", out)
            save(key, out)
            print("✓", key)
        browser.close()


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for key, spec in LOGOS.items():
            logo_hero(key, *spec, work)
            print("✓", key)
        card_heroes(list(CARDS) + LORE + ["keleti"], work)
