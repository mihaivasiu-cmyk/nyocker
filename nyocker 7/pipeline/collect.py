#!/usr/bin/env python3
"""Collects 8th-district news into docs/news.json, which the app reads.

Trusted feeds publish straight away. Bing News finds wait in docs/review.md
until someone ticks them. Only headlines, sources and links are kept: the app
sends readers to the original article, so no article text is stored.
"""
import argparse
import datetime as dt
import email.utils
import hashlib
import html
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
PIPELINE = ROOT / "pipeline"

TRUSTED = {
    "Józsefváros": "https://jozsefvaros.hu/feed/",
    "Telex": "https://telex.hu/rss/tag/jozsefvaros",
    "24.hu": "https://24.hu/tag/jozsefvaros/feed/",
}
# Bing's feed carries the real article address. Google News links stop EU readers at a cookie wall.
BING = "https://www.bing.com/news/search?format=rss&setlang=hu&mkt=hu-HU&count=50&qft=" + urllib.parse.quote('interval="9" sortbydate="1"') + "&q="
DISCOVERY = [BING + urllib.parse.quote(q) for q in ("Józsefváros", '"VIII. kerület"')]
# Its own feed sits behind a bot check, so its stories arrive through discovery.
AUTO_FROM_DISCOVERY = {"jozsefvarosujsag.hu"}
# Sites already collected directly.
DISCOVERY_SKIP = {"jozsefvaros.hu", "telex.hu", "24.hu"}
NAMES = {
    "jozsefvarosujsag.hu": "Józsefváros Újság", "index.hu": "Index", "hvg.hu": "HVG", "444.hu": "444",
    "magyarnarancs.hu": "Magyar Narancs", "origo.hu": "Origo", "welovebudapest.com": "We Love Budapest",
    "ittlakunk.hu": "Ittlakunk", "hang.hu": "Magyar Hang", "klubradio.hu": "Klubrádió", "media1.hu": "Media1",
    "portfolio.hu": "Portfolio", "infostart.hu": "Infostart", "blikk.hu": "Blikk", "vg.hu": "Világgazdaság",
    "magyarnemzet.hu": "Magyar Nemzet", "hirstart.hu": "Hírstart",
}

# Office notices rather than news.
NOT_NEWS = re.compile(
    r"dolgozzon velünk|munkatársat keres|állás(hirdetés|ajánlat)|közbeszerz|hirdetmény|"
    r"pályázat 20\d\d|pályázati (felhívás|kiírás)|közmeghallgatás|zárva tart|will be closed|"
    r"ügyfélfogadás|lakossági tájékoztató",
    re.I,
)
MAX_ITEMS = 60
MAX_AGE_DAYS = 180
REVIEW_DAYS = 14
TRACKING = re.compile(r"^(utm_|fbclid$|gclid$|ref$)", re.I)


def clean(text):
    text = re.sub(r"<[^>]+>", " ", html.unescape(text or ""))
    return re.sub(r"\s+", " ", text).strip()


def canonical(url):
    parts = urllib.parse.urlsplit((url or "").strip())
    if parts.scheme != "https" or not parts.netloc:
        return None
    query = [(k, v) for k, v in urllib.parse.parse_qsl(parts.query) if not TRACKING.match(k)]
    return urllib.parse.urlunsplit(("https", parts.netloc.lower(), parts.path, urllib.parse.urlencode(query), ""))


def key(title):
    """Matches the same story when outlets differ only in case or punctuation."""
    return re.sub(r"\W+", "", title.casefold())


def parse_date(raw):
    try:
        date = email.utils.parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        return None
    if date.tzinfo is None:
        date = date.replace(tzinfo=dt.timezone.utc)
    return date.astimezone(dt.timezone.utc)


def host(url):
    return re.sub(r"^www\.", "", urllib.parse.urlsplit(url).netloc)


def story(title, url, date, source):
    return {
        "id": hashlib.sha1(url.encode()).hexdigest()[:12],
        "title": title,
        "source": source,
        "url": url,
        "date": date.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def parse_feed(xml, source):
    """Returns stories from RSS text, skipping anything without a safe link and a date."""
    out = []
    for node in ET.fromstring(xml).iter("item"):
        title, url = clean(node.findtext("title")), canonical(node.findtext("link"))
        date = parse_date(node.findtext("pubDate"))
        if title and url and date:
            out.append(story(title, url, date, source))
    return out


def parse_discovery(xml):
    """Bing wraps each story in a click link; the article's address is in its url parameter."""
    out = []
    for node in ET.fromstring(xml).iter("item"):
        link = urllib.parse.urlsplit(node.findtext("link") or "")
        url = canonical(urllib.parse.parse_qs(link.query).get("url", [""])[0])
        title, date = clean(node.findtext("title")), parse_date(node.findtext("pubDate"))
        if title and url and date:
            out.append(story(title, url, date, NAMES.get(host(url), host(url))))
    return out


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; NyockerNews/1.0)"})
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            return response.read()
    except OSError:  # Network blips are common; one retry saves the run.
        time.sleep(5)
        with urllib.request.urlopen(request, timeout=25) as response:
            return response.read()


def read_blocked(pipeline):
    path = pipeline / "blocked.txt"
    if not path.exists():
        return set()
    return {l.strip() for l in path.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")}


def read_review(path):
    """Returns the checklist as {id: (mark, story)}. Marks: ' ' waiting, 'x' approved, 'n' rejected."""
    found = {}
    if not path.exists():
        return found
    line = re.compile(r"^- \[(.)\] (.+?) — (.+?) \((\d{4}-\d\d-\d\d)\) <(https://[^>\s]+)> `([0-9a-f]{12})`$")
    for row in path.read_text(encoding="utf-8").splitlines():
        match = line.match(row.strip())
        if match:
            mark, title, source, date, url, sid = match.groups()
            found[sid] = (mark.lower(), {"id": sid, "title": title, "source": source, "url": url, "date": f"{date}T12:00:00Z"})
    return found


def write_review(path, waiting, rejected):
    rows = [
        "# Stories waiting for approval", "",
        "Change `[ ]` to `[x]` to publish a story, or to `[n]` to drop it.",
        f"Untouched stories disappear after {REVIEW_DAYS} days.", "",
    ]
    for story in sorted(waiting, key=lambda s: s["date"], reverse=True):
        rows.append(f"- [ ] {story['title']} — {story['source']} ({story['date'][:10]}) <{story['url']}> `{story['id']}`")
    rows += ["", "<!-- rejected: " + " ".join(sorted(rejected)) + " -->", ""]
    path.write_text("\n".join(rows), encoding="utf-8")


def merge(existing, incoming, blocked, now):
    """Keeps what is already published, so a source that is down loses nothing."""
    cutoff = now - dt.timedelta(days=MAX_AGE_DAYS)
    stories, titles = {}, set()
    for story in sorted(list(incoming) + list(existing), key=lambda s: s["date"], reverse=True):
        name = key(story["title"])
        if story["id"] in stories or name in titles or story["url"] in blocked:
            continue
        if NOT_NEWS.search(story["title"]):
            continue
        if dt.datetime.fromisoformat(story["date"].replace("Z", "+00:00")) < cutoff:
            continue
        stories[story["id"]] = story
        titles.add(name)
    return sorted(stories.values(), key=lambda s: s["date"], reverse=True)[:MAX_ITEMS]


def run(now, get=fetch, docs=DOCS, pipeline=PIPELINE):
    docs.mkdir(exist_ok=True)
    news_path, review_path = docs / "news.json", docs / "review.md"
    previous = json.loads(news_path.read_text(encoding="utf-8")) if news_path.exists() else {"items": []}

    incoming, health = [], {}
    for name, url in TRUSTED.items():
        try:
            stories = parse_feed(get(url), name)
            incoming += stories
            health[name] = len(stories)
        except Exception as error:  # One bad feed must not stop the others.
            health[name] = f"failed: {type(error).__name__}"

    found, seen = [], 0
    for url in DISCOVERY:
        try:
            batch = parse_discovery(get(url))
            found += batch
            seen += len(batch)
            health["Bing News"] = seen
        except Exception as error:
            health.setdefault("Bing News", f"failed: {type(error).__name__}")
    incoming += [s for s in found if host(s["url"]) in AUTO_FROM_DISCOVERY]

    review = read_review(review_path)
    old_rejects = set()
    if review_path.exists():
        match = re.search(r"<!-- rejected: (.*?) -->", review_path.read_text(encoding="utf-8"))
        old_rejects = set(match.group(1).split()) if match else set()
    rejected = old_rejects | {sid for sid, (mark, _) in review.items() if mark == "n"}
    incoming += [story for mark, story in review.values() if mark == "x"]
    waiting = {sid: story for sid, (mark, story) in review.items() if mark == " "}

    published = merge(previous.get("items", []), incoming, read_blocked(pipeline), now)
    known_ids = {s["id"] for s in published}
    known_titles = {key(s["title"]) for s in published}
    for item in found:
        if host(item["url"]) not in DISCOVERY_SKIP and item["id"] not in rejected \
                and item["id"] not in known_ids and key(item["title"]) not in known_titles \
                and not NOT_NEWS.search(item["title"]):
            waiting.setdefault(item["id"], item)

    cutoff = (now - dt.timedelta(days=REVIEW_DAYS)).strftime("%Y-%m-%d")
    waiting = {sid: s for sid, s in waiting.items() if s["date"][:10] >= cutoff and sid not in known_ids}

    manual_path = pipeline / "manual.json"
    manual = json.loads(manual_path.read_text(encoding="utf-8")) if manual_path.exists() else []
    items = sorted(manual + [s for s in published if s["id"] not in {m["id"] for m in manual}],
                   key=lambda s: s["date"], reverse=True)[:MAX_ITEMS]

    # Only touch the timestamp when something changed, so idle runs make no commit.
    if items != previous.get("items"):
        news_path.write_text(json.dumps({
            "version": 1,
            "updated": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "items": items,
        }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    write_review(review_path, list(waiting.values()), rejected)
    return {"published": len(items), "waiting": len(waiting), "sources": health}


if __name__ == "__main__":
    argparse.ArgumentParser(description=__doc__).parse_args()
    report = run(dt.datetime.now(dt.timezone.utc))
    print(json.dumps(report, ensure_ascii=False, indent=1))
    # Every trusted source down usually means a bug here, not a quiet news day.
    if all(isinstance(report["sources"].get(name), str) for name in TRUSTED):
        sys.exit(1)
