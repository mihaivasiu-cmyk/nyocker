#!/usr/bin/env python3
"""Builds docs/events.json, which the app reads.

Events come from pipeline/events.csv, the list people edit by hand, and from any
calendar feeds in pipeline/event_feeds.json. Set EVENTS_SHEET_URL to a published
Google Sheet CSV to read the list from there instead.

Do not add sources that forbid automated collection. Facebook and Concert Budapest
both do, so anything from them goes into the list by hand, with a link to the original.
"""
import csv
import datetime as dt
import hashlib
import io
import json
import os
import pathlib
import re
import urllib.request
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUDAPEST = ZoneInfo("Europe/Budapest")
FIELDS = ("date", "time", "title", "venue", "spot", "link", "note")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; NyockerEvents/1.0)"})
    with urllib.request.urlopen(request, timeout=25) as response:
        return response.read().decode("utf-8", "replace")


def make_event(title, venue, start, source, spot="", link="", note=""):
    event = {
        "id": hashlib.sha1(f"{start.date()}|{key(title)}".encode()).hexdigest()[:12],
        "title": title,
        "venue": venue,
        "start": start.isoformat(timespec="minutes"),
        "source": source,
    }
    if spot:
        event["spot"] = spot
    if link:
        event["link"] = link
    if note:
        event["note"] = note
    return event


def key(title):
    return re.sub(r"\W+", "", title.casefold())


def parse_list(text):
    """Returns (events, problems). A bad row is reported and skipped, never fatal."""
    events, problems = [], []
    for number, row in enumerate(csv.DictReader(io.StringIO(text)), start=2):
        row = {name: (row.get(name) or "").strip() for name in FIELDS}
        if not any(row.values()):
            continue
        try:
            when = dt.datetime.strptime(f"{row['date']} {row['time'] or '00:00'}", "%Y-%m-%d %H:%M")
        except ValueError:
            problems.append(f"row {number}: date must look like 2026-11-04 and time like 19:00")
            continue
        if not row["title"] or not row["venue"]:
            problems.append(f"row {number}: needs a title and a venue")
            continue
        if row["link"] and not row["link"].startswith("https://"):
            problems.append(f"row {number}: link must start with https://")
            continue
        events.append(make_event(row["title"], row["venue"], when.replace(tzinfo=BUDAPEST), "list",
                                 row["spot"], row["link"], row["note"]))
    return events, problems


def parse_calendar(text, venue, spot=""):
    """Reads the parts of an iCalendar feed we need. Test entries are left out."""
    lines = re.sub(r"\r?\n[ \t]", "", text).splitlines()
    events, current = [], None
    for line in lines:
        if line == "BEGIN:VEVENT":
            current = {}
        elif line == "END:VEVENT" and current is not None:
            title, start = current.get("SUMMARY", ""), parse_stamp(current.get("DTSTART", ""))
            link = current.get("URL", "")
            if title and start and key(title) not in {"teszt", "test"}:
                events.append(make_event(title.replace("\\,", ","), venue, start, f"calendar:{venue}", spot,
                                         link if link.startswith("https://") else ""))
            current = None
        elif current is not None and ":" in line:
            name, value = line.split(":", 1)
            current[name.split(";")[0]] = value.strip()
    return events


def parse_stamp(raw):
    try:
        if raw.endswith("Z"):
            return dt.datetime.strptime(raw, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc).astimezone(BUDAPEST)
        if "T" in raw:
            return dt.datetime.strptime(raw, "%Y%m%dT%H%M%S").replace(tzinfo=BUDAPEST)
        return dt.datetime.strptime(raw, "%Y%m%d").replace(tzinfo=BUDAPEST)
    except ValueError:
        return None


def run(now, get=fetch, docs=ROOT / "docs", pipeline=ROOT / "pipeline", sheet=None):
    docs.mkdir(exist_ok=True)
    path = docs / "events.json"
    previous = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"items": []}

    report = {"sources": {}, "problems": []}
    try:
        text = get(sheet) if sheet else (pipeline / "events.csv").read_text(encoding="utf-8")
        events, report["problems"] = parse_list(text)
        report["sources"]["list"] = len(events)
    except Exception as error:  # Keep what is published if the sheet can't be reached.
        events = [e for e in previous["items"] if e["source"] == "list"]
        report["sources"]["list"] = f"failed: {type(error).__name__}"

    feeds_path = pipeline / "event_feeds.json"
    for feed in json.loads(feeds_path.read_text(encoding="utf-8")) if feeds_path.exists() else []:
        name = feed["venue"]
        try:
            found = parse_calendar(get(feed["url"]), name, feed.get("spot", ""))
            events += found
            report["sources"][name] = len(found)
        except Exception as error:
            events += [e for e in previous["items"] if e["source"] == f"calendar:{name}"]
            report["sources"][name] = f"failed: {type(error).__name__}"

    today = now.astimezone(BUDAPEST).date().isoformat()
    unique = {}
    for event in sorted(events, key=lambda e: e["source"] != "list"):  # The hand list wins a tie.
        if event["start"][:10] >= today:
            unique.setdefault(event["id"], event)
    items = sorted(unique.values(), key=lambda e: e["start"])

    if items != previous.get("items"):
        path.write_text(json.dumps({
            "version": 1,
            "updated": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "items": items,
        }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    report["published"] = len(items)
    return report


if __name__ == "__main__":
    result = run(dt.datetime.now(dt.timezone.utc), sheet=os.environ.get("EVENTS_SHEET_URL") or None)
    # A typo in the list is shown here but must not stop the rest of the run.
    print(json.dumps(result, ensure_ascii=False, indent=1))
