"""The Zaydi-library inputs: each hash link, the extraction's state, the book's facts and the reviewer's record."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from hqpack.errors import PackError
from hqpack.ziydia_inputs import PageParagraphs, read_book_inputs, read_review_record
from tests import ziydia_factory as zf


class _Case(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.book = zf.Book(Path(temporary.name) / "with space").write()

    def read(self, pages_sha256=None, passages_sha256=None):
        book = self.book
        return read_book_inputs(
            book.root / "extraction",
            book.root / "links",
            book.book,
            pages_sha256 or zf.sha256((book.extraction / "pages.jsonl").read_bytes()),
            passages_sha256 or zf.sha256((book.links / "passages.jsonl").read_bytes()),
            read_review_record(book.path("review.json").read_bytes()),
        )

    def edit_json(self, path, change):
        value = json.loads(path.read_bytes())
        change(value)
        path.write_bytes(zf.dumps(value))

    def assert_refused(self, expected):
        with self.assertRaises(PackError) as caught:
            self.read()
        self.assertIn(expected, str(caught.exception))
        self.assertTrue(str(caught.exception).isascii(), str(caught.exception))
        self.assertNotIn("Synthetic", str(caught.exception))


class InputsTest(_Case):
    def test_reads_the_book(self):
        inputs = self.read()
        self.assertEqual(inputs.url, "https://ziydia.com/book/183")
        self.assertEqual(inputs.date_added, "2020-01-02")
        self.assertEqual(inputs.facts.title, "Synthetic book " + zf.PHRASE)
        self.assertEqual(inputs.facts.publisher, "Synthetic publisher")
        self.assertEqual(inputs.facts.edition, "Synthetic edition 1")
        self.assertIsNone(inputs.facts.editor)
        self.assertEqual(sorted(inputs.pages), [10, 11, 12])
        self.assertEqual(len(inputs.entries), len(zf.ENTRIES))
        self.assertEqual(inputs.outcomes[5], "not_found")
        self.assertEqual(sorted(inputs.outcomes), [3, 4, 5, 6, 7, 10])

    def test_facts_the_card_does_not_give_are_null(self):
        self.book.meta["card"] = self.book.meta["card"][:1]
        self.book.write()
        facts = self.read().facts
        self.assertIsNone(facts.publisher)
        self.assertIsNone(facts.edition)
        self.assertIsNone(facts.editor)

    def test_the_description_hashes(self):
        with self.assertRaisesRegex(PackError, "pages.jsonl has SHA-256 [0-9a-f]{64}; the description's pages_sha256 is 0{64}"):
            self.read(pages_sha256="0" * 64)
        with self.assertRaisesRegex(PackError, "passages.jsonl has SHA-256 [0-9a-f]{64}; the description's passages_sha256"):
            self.read(passages_sha256="0" * 64)

    def test_each_hash_link_of_the_linker_and_the_record(self):
        links = self.book.links
        cases = (
            (links / "report.json", lambda r: r["input"].update(pages_sha256="0" * 64), "report.json: input.pages_sha256"),
            (links / "report.json", lambda r: r.update(passages_sha256="0" * 64), "report.json: passages_sha256"),
            (links / "compare.json", lambda c: c.update(passages_sha256="0" * 64), "compare.json: passages_sha256"),
            (self.book.path("review.json"), lambda r: r.update(passages_sha256="0" * 64), "review record: passages_sha256"),
            (links / "compare.json", lambda c: c.update(text_from_book=515), "review record: compare_sha256 is not the hash"),
            (self.book.path("review.json"), lambda r: r.update(book=184), "review record: book is 184, not 183"),
        )
        for path, change, expected in cases:
            with self.subTest(expected=expected):
                self.book.write()
                self.edit_json(path, change)
                self.assert_refused(expected)

    def test_the_sample_is_bound_by_its_hash(self):
        (self.book.links / "sample.html").write_bytes(b"<!doctype html><title>another sample</title>\n")
        self.assert_refused("review record: sample.sample_sha256 is not the hash of sample.html")

    def test_a_missing_file_is_named(self):
        (self.book.links / "sample.html").unlink()
        self.assert_refused("sample.html cannot be read")

    def test_the_extraction_must_be_done(self):
        for state in ({"done": False}, {"pages": 3}, {"done": 1}, []):
            with self.subTest(state=state):
                self.book.state = state
                self.book.write()
                self.assert_refused("state.json does not say done")

    def test_the_linker_profile(self):
        self.book.profile = "items"
        self.book.write()
        self.assert_refused("book 183 is not linked with one of the linker's six profiles")

    def test_the_book_is_the_same_everywhere(self):
        self.book.write()
        self.edit_json(self.book.links / "report.json", lambda r: r.update(book=514))
        self.assert_refused("report.json is not the linker's report of book 183")

    def test_the_meta(self):
        cases = (
            (lambda m: m.update(url="https://ziydia.com/book/184"), "meta.json: url is not https://ziydia.com/book/183"),
            (lambda m: m.update(url="http://ziydia.com/book/183"), "meta.json: url is not"),
            (lambda m: m.update(id=184), "meta.json: id is not 183"),
            (lambda m: m.update(title=""), "meta.json title is empty"),
            (lambda m: m.update(author=" Synthetic"), "meta.json author has spaces at its edges"),
            (lambda m: m.update(title="Synthetic\nbook"), "meta.json title holds U+000A"),
            (lambda m: m.pop("date_added"), "meta.json.date_added is missing"),
            (lambda m: m.update(date_added="\u0662\u0660\u0662\u0660"), "date_added is not printable ASCII"),
            (lambda m: m.update(fetched=1), "meta.json has an unknown key fetched"),
            (lambda m: m["card"].append({"label": "\u0627\u0644\u0645\u062d\u0642\u0642", "value": "Synthetic"}),
             "meta.json card[3]: the label is not one the tafsir pack knows (D-187)"),
            (lambda m: m["card"].append({"label": "Synthetic label", "value": "Synthetic"}),
             "meta.json card[3]: the label is not one"),
            (lambda m: m["card"].append(dict(m["card"][1])), "meta.json card[3]: the label repeats"),
            (lambda m: m["card"][1].update(value=""), "meta.json card[1] value is empty"),
            (lambda m: m["card"][1].update(value="Synthetic "), "meta.json card[1] value has spaces at its edges"),
            (lambda m: m["card"][2].update(value=None), "meta.json card[2] value is empty"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                self.book.write()
                self.edit_json(self.book.extraction / "meta.json", change)
                self.assert_refused(expected)

    def test_pages(self):
        cases = (
            (lambda p: p.update(html=p["html"] + "\ufffd"), "pages.jsonl line 1: html holds U+FFFD"),
            (lambda p: p.update(html="\ufeff" + p["html"]), "pages.jsonl line 1: html holds U+FEFF"),
            (lambda p: p.update(book=184), "pages.jsonl line 1 is not a page of book 183"),
            (lambda p: p.update(url_page="x"), "pages.jsonl line 1: url_page is not a site page number"),
            (lambda p: p.update(url="https://ziydia.com/book/1830/page/10"), "pages.jsonl line 1: url is not a page of"),
            (lambda p: p.update(url_page="11"), "pages.jsonl line 2: site page 11 comes twice"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                self.book.write()
                path = self.book.extraction / "pages.jsonl"
                lines = path.read_bytes().decode("utf-8").split("\r\n")
                first = json.loads(lines[0])
                change(first)
                lines[0] = json.dumps(first, ensure_ascii=False)
                data = "\r\n".join(lines).encode("utf-8")
                path.write_bytes(data)
                self.edit_json(self.book.links / "report.json", lambda r: r["input"].update(pages_sha256=zf.sha256(data)))
                with self.assertRaises(PackError) as caught:
                    self.read(pages_sha256=zf.sha256(data))
                self.assertIn(expected, str(caught.exception))

    def test_outcomes_cover_every_linked_entry(self):
        self.book.write()
        self.edit_json(self.book.links / "compare.json", lambda c: c["outcomes"].pop("3"))
        self.book.write_file("review.json", self._review_for_current_compare())
        self.assert_refused("compare.json: outcomes cover 5 entries, not the 6 of kind passage")
        self.edit_json(self.book.links / "compare.json", lambda c: c.pop("outcomes"))
        self.book.write_file("review.json", self._review_for_current_compare())
        self.assert_refused("compare.json has no outcomes")

    def _review_for_current_compare(self):
        record = json.loads(self.book.path("review.json").read_bytes())
        record["compare_sha256"] = zf.sha256((self.book.links / "compare.json").read_bytes())
        return json.dumps(record).encode("ascii")

    def test_the_record_names_only_entries_that_can_ship(self):
        for cleared, expected in (([99], "cleared names 99, which passages.jsonl lacks"), ([8], "cleared names 8, an entry that never ships")):
            with self.subTest(expected=expected):
                self.book.cleared = cleared
                self.book.write()
                self.assert_refused(expected)
        self.book.cleared, self.book.excluded = [], [9]
        self.book.write()
        self.assert_refused("excluded names 9, an entry that never ships")


class ReviewRecordTest(unittest.TestCase):
    RECORD = {
        "book": 183,
        "passages_sha256": "1" * 64,
        "compare_sha256": "2" * 64,
        "sample": {"reviewer": "Synthetic reviewer", "date": "2026-01-03", "sample_sha256": "3" * 64},
        "cleared": [{"n": 4, "reviewer": "Synthetic reviewer", "date": "2026-01-03"}],
        "excluded": [{"n": 5, "reviewer": "Another reviewer", "date": "2026-01-04"}],
    }

    def encode(self, record):
        return json.dumps(record).encode("ascii")

    def test_reads_a_record(self):
        record = read_review_record(self.encode(self.RECORD))
        self.assertEqual(record.book, 183)
        self.assertEqual(sorted(record.cleared), [4])
        self.assertEqual(record.excluded[5].reviewer, "Another reviewer")
        self.assertEqual(record.sample["sample_sha256"], "3" * 64)

    def test_refusals(self):
        cases = (
            (lambda r: r.pop("sample"), "sample is missing"),
            (lambda r: r.update(text="x"), "has an unknown key text"),
            (lambda r: r["sample"].pop("sample_sha256"), "sample.sample_sha256 is missing"),
            (lambda r: r["sample"].update(date="2026-13-01"), "sample.date must be a real date"),
            (lambda r: r.update(compare_sha256="2" * 63), "compare_sha256 must be lowercase hex SHA-256"),
            (lambda r: r["cleared"].append(dict(r["cleared"][0])), "cleared[1].n 4 repeats"),
            (lambda r: r["excluded"][0].update(n=0), "excluded[0].n must be a positive integer"),
            (lambda r: r["excluded"][0].update(n=True), "excluded[0].n must be a positive integer"),
            (lambda r: r["cleared"][0].update(reviewer=" x"), "cleared[0].reviewer has spaces at its edges"),
            (lambda r: r.update(cleared={}), "cleared is not a list"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                record = json.loads(json.dumps(self.RECORD))
                change(record)
                with self.assertRaises(PackError) as caught:
                    read_review_record(self.encode(record))
                self.assertIn(expected, str(caught.exception))
                self.assertTrue(str(caught.exception).startswith("review record: "))

    def test_the_record_is_ascii(self):
        data = self.encode(self.RECORD).replace(b"Another", "\u0627".encode("utf-8"))
        with self.assertRaisesRegex(PackError, "review record: the file is not ASCII"):
            read_review_record(data)


class PageParagraphsTest(unittest.TestCase):
    def test_p3_each_paragraph_is_its_pages_once(self):
        a, b = zf.para("Synthetic a"), zf.para("Synthetic b")
        pages = PageParagraphs({1: a + "\n" + b + "\n" + a})
        pages.take(1, a, "p1")
        pages.take(1, b, "p2")
        pages.take(1, a, "p3")
        with self.assertRaisesRegex(PackError, r"p4 is not a paragraph of site page 1 in pages.jsonl \(P3\)"):
            pages.take(1, a, "p4")
        with self.assertRaisesRegex(PackError, r"p5: site page 2 is not in pages.jsonl \(P3\)"):
            pages.take(2, a, "p5")
        with self.assertRaisesRegex(PackError, r"is not a paragraph of site page 1"):
            PageParagraphs({1: a}).take(1, zf.para("Synthetic a "), "p6")

    def test_a_page_must_be_paragraphs_only(self):
        with self.assertRaisesRegex(PackError, "site page 3 is not a sequence of paragraphs"):
            PageParagraphs({3: "Synthetic " + zf.para("x")}).take(3, zf.para("x"), "p")


if __name__ == "__main__":
    unittest.main()
