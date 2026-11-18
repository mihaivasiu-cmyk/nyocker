import datetime as dt
import json
import pathlib
import tempfile
import unittest

import collect_events as ce

NOW = dt.datetime(2026, 11, 2, 12, tzinfo=dt.timezone.utc)
HEAD = "date,time,title,venue,spot,link,note\n"
CAL = (
    "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nSUMMARY:Teszt\r\nDTSTART;VALUE=DATE:20261201\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nSUMMARY:Hosszú\r\n  cím\\, koncert\r\nDTSTART:20261105T180000Z\r\n"
    "URL:https://auroraonline.hu/e/1\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
)


class Events(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rows, feeds=None):
        (self.dir / "events.csv").write_text(HEAD + rows, encoding="utf-8")
        if feeds:
            (self.dir / "event_feeds.json").write_text(json.dumps(feeds), encoding="utf-8")

    def run_it(self, get=None, now=NOW):
        return ce.run(now, get, self.dir, self.dir)

    def items(self):
        return json.loads((self.dir / "events.json").read_text(encoding="utf-8"))["items"]

    def test_list_row_publishes_in_budapest_time(self):
        self.write("2026-11-04,19:00,Jü,Gólya,golya,https://facebook.com/events/1,Free\n")
        self.run_it()
        event = self.items()[0]
        self.assertEqual(event["start"], "2026-11-04T19:00+01:00")
        self.assertEqual((event["spot"], event["note"]), ("golya", "Free"))

    def test_summer_date_uses_summer_time(self):
        self.write("2027-07-04,19:00,Kert,Gólya,,,\n")
        self.run_it()
        self.assertEqual(self.items()[0]["start"], "2027-07-04T19:00+02:00")

    def test_past_events_drop_but_today_stays(self):
        self.write("2026-11-01,19:00,Tegnap,Gólya,,,\n2026-11-02,09:00,Ma,Gólya,,,\n")
        self.run_it()
        self.assertEqual([e["title"] for e in self.items()], ["Ma"])

    def test_bad_rows_are_reported_not_published(self):
        self.write("4 Nov,19:00,Rossz dátum,Gólya,,,\n2026-11-04,19:00,,Gólya,,,\n"
                   "2026-11-04,19:00,Rossz link,Gólya,,http://x.hu,\n2026-11-05,,Jó,Gólya,,,\n")
        report = self.run_it()
        self.assertEqual(len(report["problems"]), 3)
        self.assertEqual([e["title"] for e in self.items()], ["Jó"])

    def test_calendar_feed_skips_test_entries_and_converts_time(self):
        self.write("", [{"venue": "Auróra", "spot": "aurora", "url": "https://x/ical"}])
        self.run_it(lambda url: CAL)
        event = self.items()[0]
        self.assertEqual(len(self.items()), 1)
        self.assertEqual(event["title"], "Hosszú cím, koncert")
        self.assertEqual(event["start"], "2026-11-05T19:00+01:00")

    def test_failed_calendar_keeps_its_published_events(self):
        self.write("", [{"venue": "Auróra", "url": "https://x/ical"}])
        self.run_it(lambda url: CAL)

        def down(url):
            raise OSError("down")
        report = self.run_it(down)
        self.assertEqual(len(self.items()), 1)
        self.assertIn("failed", report["sources"]["Auróra"])

    def test_same_event_in_list_and_calendar_appears_once(self):
        self.write("2026-11-05,20:00,Hosszú cím koncert,Auróra,aurora,https://fb.com/1,Hand note\n",
                   [{"venue": "Auróra", "url": "https://x/ical"}])
        self.run_it(lambda url: CAL)
        self.assertEqual(len(self.items()), 1)
        self.assertEqual(self.items()[0]["note"], "Hand note")

    def test_unreachable_sheet_keeps_list_events(self):
        self.write("2026-11-05,20:00,Koncert,Gólya,,,\n")
        self.run_it()

        def down(url):
            raise OSError("down")
        report = ce.run(NOW, down, self.dir, self.dir, sheet="https://sheet")
        self.assertEqual(len(self.items()), 1)
        self.assertIn("failed", report["sources"]["list"])


if __name__ == "__main__":
    unittest.main()
