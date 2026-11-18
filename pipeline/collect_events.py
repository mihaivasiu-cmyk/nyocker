#!/usr/bin/env python3
"""Builds docs/events.json, which the app reads.

Events come from pipeline/events.csv, the list people edit by hand, and from any
calendar feeds in pipeline/event_feeds.json (a Google Calendar's iCal address works;
a private one goes in a repository secret named by the feed's url_env). Set EVENTS_SHEET_URL to a published
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


HORIZON = dt.timedelta(days=120)  # How far ahead repeating events are spelled out.
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def unescape(value):
    return re.sub(r"\\([\\,;nN])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), value)


def read_vevents(text):
    """Each VEVENT as {NAME: [(params, value), ...]}; folded lines are joined first."""
    lines = re.sub(r"\r?\n[ \t]", "", text).splitlines()
    found, current = [], None
    for line in lines:
        if line == "BEGIN:VEVENT":
            current = {}
        elif line == "END:VEVENT" and current is not None:
            found.append(current)
            current = None
        elif current is not None and ":" in line:
            head, value = line.split(":", 1)
            name, *rest = head.split(";")
            params = dict(part.split("=", 1) for part in rest if "=" in part)
            current.setdefault(name.upper(), []).append((params, value.strip()))
    return found


def first(props, name):
    entry = props.get(name)
    return entry[0] if entry else ({}, "")


def stamp(props, name):
    params, value = first(props, name)
    return parse_stamp(value, params.get("TZID"))


def describe(props):
    """A short note and a link from the event's description. Google often writes HTML there."""
    raw = unescape(first(props, "DESCRIPTION")[1])
    hrefs = re.findall(r'href="(https://[^"]+)"', raw)
    text = re.sub(r"<br\s*/?>|</p>", "\n", raw, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text).replace("&amp;", "&").replace("&nbsp;", " ")
    urls = hrefs + re.findall(r"https://[^\s<>\"]+", text)
    text = re.sub(r"https?://\S+", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > 200:
        text = text[:197].rsplit(" ", 1)[0] + "…"
    link = first(props, "URL")[1]
    if not link.startswith("https://"):
        link = urls[0] if urls else ""
    return text, link


def occurrences(start, rule, until_window):
    """Start times of a repeating event up to until_window. Handles the rules calendars
    actually use: daily, weekly on given days, monthly by date or by "2nd Friday", yearly."""
    parts = dict(p.split("=", 1) for p in rule.split(";") if "=" in p)
    freq = parts.get("FREQ", "")
    every = max(int(parts.get("INTERVAL", "1") or 1), 1)
    count = int(parts["COUNT"]) if parts.get("COUNT", "").isdigit() else None
    until = parse_stamp(parts["UNTIL"]) if "UNTIL" in parts else None
    end = min(until_window, until) if until else until_window
    zone, wall = start.tzinfo, start.replace(tzinfo=None)
    days = [d for d in parts.get("BYDAY", "").split(",") if d]

    def at(day):
        return dt.datetime.combine(day, wall.time()).replace(tzinfo=zone)

    def candidates():
        if freq == "DAILY":
            for n in range(0, 15000, every):
                yield at(wall.date() + dt.timedelta(days=n))
        elif freq == "WEEKLY":
            wanted = sorted(WEEKDAYS.index(d[-2:]) for d in days if d[-2:] in WEEKDAYS) or [wall.weekday()]
            monday = wall.date() - dt.timedelta(days=wall.weekday())
            for week in range(0, 2000, every):
                for weekday in wanted:
                    yield at(monday + dt.timedelta(weeks=week, days=weekday))
        elif freq == "MONTHLY":
            month_days = [int(d) for d in parts.get("BYMONTHDAY", "").split(",") if d.lstrip("-").isdigit()]
            for n in range(0, 600, every):
                y, m = divmod(wall.month - 1 + n, 12)
                year, month = wall.year + y, m + 1
                length = (dt.date(year + month // 12, month % 12 + 1, 1) - dt.timedelta(days=1)).day
                picks = []
                for d in days:
                    match = re.fullmatch(r"([+-]?\d)?(MO|TU|WE|TH|FR|SA|SU)", d)
                    if not match:
                        continue
                    weekday = WEEKDAYS.index(match.group(2))
                    dates = [dt.date(year, month, x) for x in range(1, length + 1)
                             if dt.date(year, month, x).weekday() == weekday]
                    if match.group(1):
                        index = int(match.group(1))
                        if -len(dates) <= index <= len(dates) and index != 0:
                            picks.append(dates[index - 1 if index > 0 else index])
                    else:
                        picks += dates
                for x in month_days or ([] if days else [wall.day]):
                    x = x if x > 0 else length + 1 + x
                    if 1 <= x <= length:
                        picks.append(dt.date(year, month, x))
                for day in sorted(set(picks)):
                    yield at(day)
        elif freq == "YEARLY":
            for n in range(0, 50, every):
                try:
                    yield at(wall.date().replace(year=wall.year + n))
                except ValueError:  # 29 February
                    continue
        else:
            yield start

    made = 0
    for when in candidates():
        if when < start:
            continue
        if when > end or (count is not None and made >= count):
            return
        made += 1
        yield when


def parse_calendar(text, venue, spot="", now=None):
    """Reads an iCalendar feed (a Google Calendar's iCal address works). Repeating events
    are spelled out for the next few months; cancelled ones and test entries are left out."""
    now = now or dt.datetime.now(dt.timezone.utc)
    window = now + HORIZON
    source = f"calendar:{venue}"
    vevents = read_vevents(text)
    changed = {}  # (UID, original start) -> the edited copy of one repeat
    for props in vevents:
        original = stamp(props, "RECURRENCE-ID")
        if original:
            changed[(first(props, "UID")[1], original)] = props

    def make(props, start):
        title = unescape(first(props, "SUMMARY")[1]).strip()
        if not title or not start or key(title) in {"teszt", "test"}:
            return None
        if first(props, "STATUS")[1].upper() == "CANCELLED":
            return None
        note, link = describe(props)
        return make_event(title, venue, start, source, spot, link, note)

    events = []
    for props in vevents:
        if "RECURRENCE-ID" in props:
            continue
        start = stamp(props, "DTSTART")
        rule = first(props, "RRULE")[1]
        if not start:
            continue
        if not rule:
            event = make(props, start)
            if event:
                events.append(event)
            continue
        skipped = set()
        for params, value in props.get("EXDATE", []):
            for one in value.split(","):
                when = parse_stamp(one, params.get("TZID"))
                if when:
                    skipped.add(when)
        uid = first(props, "UID")[1]
        for when in occurrences(start, rule, window):
            if when in skipped or when.date() in {s.date() for s in skipped if s.time() == dt.time(0)}:
                continue
            edit = changed.pop((uid, when), None)
            event = make(edit, stamp(edit, "DTSTART") or when) if edit else make(props, when)
            if event:
                events.append(event)
    for props in changed.values():  # An edited repeat whose series isn't in the feed any more.
        event = make(props, stamp(props, "DTSTART"))
        if event:
            events.append(event)
    return events


def parse_stamp(raw, tzid=None):
    try:
        zone = ZoneInfo(tzid) if tzid else BUDAPEST
    except Exception:
        zone = BUDAPEST
    try:
        if raw.endswith("Z"):
            return dt.datetime.strptime(raw, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc).astimezone(BUDAPEST)
        if "T" in raw:
            return dt.datetime.strptime(raw, "%Y%m%dT%H%M%S").replace(tzinfo=zone).astimezone(BUDAPEST)
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
        # A private calendar's secret iCal address lives in a repository secret, named by url_env.
        url = feed.get("url") or os.environ.get(feed.get("url_env", ""), "")
        if not url:
            report["sources"][name] = f"skipped: set {feed.get('url_env', 'url')}"
            continue
        try:
            found = parse_calendar(get(url), name, feed.get("spot", ""), now)
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
