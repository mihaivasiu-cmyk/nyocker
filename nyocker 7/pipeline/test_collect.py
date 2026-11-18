import datetime as dt
import json
import pathlib
import tempfile
import unittest

import collect

NOW = dt.datetime(2026, 11, 2, 12, tzinfo=dt.timezone.utc)


def rss(*rows):
    items = "".join(
        f"<item><title>{t}</title><link>{u}</link><pubDate>{d}</pubDate>{extra}</item>"
        for t, u, d, extra in rows
    )
    return f"<rss><channel>{items}</channel></rss>".encode()


DAY = "Sun, 01 Nov 2026 10:00:00 +0100"
ONE = rss(("Felújítják a Teleki teret", "https://telex.hu/a/1?utm_source=x", DAY, ""))
BING = "https://www.bing.com/news/apiclick.aspx?url="
GOOGLE = rss(("Új kávézó a Palotanegyedben", BING + "https%3a%2f%2fwww.pelda.hu%2fkavezo", DAY, ""))


def feeds(trusted=ONE, google=GOOGLE):
    def get(url):
        data = google if "bing.com" in url else trusted if "telex" in url else rss()
        if isinstance(data, Exception):
            raise data
        return data
    return get


class Collect(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.docs = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def news(self):
        return json.loads((self.docs / "news.json").read_text(encoding="utf-8"))["items"]

    def test_trusted_story_publishes_without_tracking(self):
        collect.run(NOW, feeds(), self.docs, self.docs)
        self.assertEqual(self.news()[0]["url"], "https://telex.hu/a/1")
        self.assertEqual(self.news()[0]["source"], "Telex")

    def test_google_find_waits_for_approval_then_publishes(self):
        collect.run(NOW, feeds(), self.docs, self.docs)
        self.assertNotIn("Új kávézó", json.dumps(self.news(), ensure_ascii=False))
        path = self.docs / "review.md"
        path.write_text(path.read_text(encoding="utf-8").replace("- [ ]", "- [x]"), encoding="utf-8")
        collect.run(NOW, feeds(), self.docs, self.docs)
        story = next(s for s in self.news() if "kávézó" in s["title"])
        self.assertEqual(story["title"], "Új kávézó a Palotanegyedben")
        self.assertEqual(story["source"], "pelda.hu")
        self.assertEqual(story["url"], "https://www.pelda.hu/kavezo")
        self.assertNotIn("kávézó", path.read_text(encoding="utf-8"))

    def test_rejected_story_never_comes_back(self):
        collect.run(NOW, feeds(), self.docs, self.docs)
        path = self.docs / "review.md"
        path.write_text(path.read_text(encoding="utf-8").replace("- [ ]", "- [n]"), encoding="utf-8")
        collect.run(NOW, feeds(), self.docs, self.docs)
        collect.run(NOW, feeds(), self.docs, self.docs)
        self.assertNotIn("kávézó", path.read_text(encoding="utf-8").split("<!--")[0])

    def test_failed_source_keeps_published_stories(self):
        collect.run(NOW, feeds(), self.docs, self.docs)
        report = collect.run(NOW, feeds(trusted=OSError("down"), google=OSError("down")), self.docs, self.docs)
        self.assertEqual(len(self.news()), 1)
        self.assertIn("failed", report["sources"]["Telex"])

    def test_same_headline_from_two_links_appears_once(self):
        twice = rss(("Felújítják a Teleki teret!", "https://telex.hu/a/1", DAY, ""),
                    ("felújítják a teleki teret", "https://telex.hu/a/2", DAY, ""))
        collect.run(NOW, feeds(trusted=twice), self.docs, self.docs)
        self.assertEqual(len(self.news()), 1)

    def test_job_ads_and_unsafe_links_are_dropped(self):
        junk = rss(("Dolgozzon velünk! Irodavezetőt keresünk", "https://telex.hu/a/3", DAY, ""),
                   ("Hír nem biztonságos linkkel", "http://telex.hu/a/4", DAY, ""),
                   ("Hír dátum nélkül", "https://telex.hu/a/5", "nonsense", ""))
        collect.run(NOW, feeds(trusted=junk), self.docs, self.docs)
        self.assertFalse((self.docs / "news.json").exists() and self.news())

    def test_local_paper_publishes_through_discovery(self):
        paper = rss(("Mindenszentek a sírkertben", BING + "https%3a%2f%2fjozsefvarosujsag.hu%2fmindenszentek", DAY, ""))
        collect.run(NOW, feeds(google=paper), self.docs, self.docs)
        story = next(s for s in self.news() if s["title"] == "Mindenszentek a sírkertben")
        self.assertEqual((story["source"], story["url"]), ("Józsefváros Újság", "https://jozsefvarosujsag.hu/mindenszentek"))

    def test_html_in_headline_is_stripped(self):
        tagged = rss(("&lt;b&gt;Tér&lt;/b&gt; &amp;amp; park", "https://telex.hu/a/6", DAY, ""))
        collect.run(NOW, feeds(trusted=tagged), self.docs, self.docs)
        self.assertEqual(self.news()[0]["title"], "Tér & park")

    def test_idle_run_leaves_timestamp_alone(self):
        collect.run(NOW, feeds(), self.docs, self.docs)
        first = (self.docs / "news.json").read_text(encoding="utf-8")
        collect.run(NOW + dt.timedelta(hours=3), feeds(), self.docs, self.docs)
        self.assertEqual((self.docs / "news.json").read_text(encoding="utf-8"), first)


if __name__ == "__main__":
    unittest.main()
