# Nyócker news and events

`feeds.yml` runs every 3 hours and publishes `docs/news.json` and `docs/events.json`,
which the app reads. Editing any file below also triggers a run.

## Add an event

Add a row to `pipeline/events.csv`:

| Column | Example | Notes |
|---|---|---|
| date | 2026-11-04 | Required |
| time | 19:00 | Budapest time |
| title | Jü live | Required |
| venue | Gólya | Required |
| spot | golya | Optional. The spot's `id` in `Nyocker/content.json`, which adds the On map button |
| link | https://www.facebook.com/events/123/ | Optional, must start with https:// |
| note | Free entry | Optional, in our own words |

Past events disappear by themselves.

To keep the list in a Google Sheet instead, use the same columns, publish the sheet as
CSV, and save that address as the repository variable `EVENTS_SHEET_URL`.

## Weekly check, about 20 minutes

1. Look through the venues' Facebook pages and Magyar Narancs's weekly listing.
2. Add each event by hand, with a link to the original.

Never automate this. Meta's and Concert Budapest's terms both forbid automated collection.

## Add a venue's calendar feed

If a venue offers an iCal address, add it to `pipeline/event_feeds.json`.

## Approve news

Open `docs/review.md` and change `[ ]` to `[x]` to publish a story, or to `[n]` to drop it.
To remove a published story for good, add its link to `pipeline/blocked.txt`.
