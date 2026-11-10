"""The `tafsir` command end to end on a synthetic Zaydi-library book: the pack, its refusals and its exit codes."""

from __future__ import annotations

import io
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from hqpack import cli, tafsir_build
from hqpack.tafsir_database import StoredTafsirTexts
from hqpack.verify import Report
from hqpack.verify_tafsir import verify_tafsir_pack
from tests import ziydia_factory as zf

REPO = Path(__file__).resolve().parents[3]
AMIRI = REPO / "assets" / "fonts" / "AmiriQuran-Regular.ttf"
PACK = ("synthetic-tafsir-183", "1")
ROWS = [
    (1, 1, 0, 0, "Synthetic surah-level opening " + zf.PHRASE),
    (2, 1, 1, 3, "Synthetic lead: first part\nSynthetic quoted words\u2063[3] second part"),
    (3, 2, 2, 3, "(2) Synthetic name " + zf.HONORIFIC + " and Synthetic honorific end \ufdfa ..."),
    (4, 3, 1, 1, "Synthetic last"),
]
MANIFEST_KEYS = [
    "format", "format_version", "id", "kind", "version", "changelog", "riwaya", "sources", "files", "counts", "reviews",
]


class _Case(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name) / "with space"
        self.book = zf.Book(self.work).write()

    @property
    def pack(self):
        return self.book.out.joinpath(*PACK)

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main([str(a) for a in argv], out=out, err=err)
        text = out.getvalue() + err.getvalue()
        self.assertTrue(text.isascii(), text)
        for value in ("Synthetic", zf.SENTINEL, "surah-level opening"):
            self.assertNotIn(value, text)
        return code, out.getvalue(), err.getvalue()

    def tafsir(self, **replace):
        return self.run_cli("tafsir", *self.book.args(**replace))

    def assert_refused(self, expected, **replace):
        code, out, err = self.tafsir(**replace)
        self.assertEqual(code, cli.EX_DATAERR, out + err)
        self.assertIn(expected, err)
        self.assert_nothing_left()
        return err

    def assert_nothing_left(self):
        if self.book.out.exists():
            self.assertEqual([p.name for p in self.book.out.iterdir()], [])


class TafsirPackTest(_Case):
    def test_builds_a_pack_that_verifies(self):
        report = self.work / "held.json"
        code, out, _ = self.tafsir(report=report)
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 4 surah-level 1", out)
        self.assertIn("entries shipped 5 held 2; paragraphs 5, empty left out 1; honorific codes replaced 2", out)
        self.assertRegex(out, r"tafsir.sqlite sha256 [0-9a-f]{64}")
        self.assertIn("verified", out)
        self.assertIn("unsigned", out)
        self.assertEqual(sorted(p.name for p in self.pack.iterdir()), ["manifest.json", "tafsir.sqlite"])
        self.assertEqual(verify_tafsir_pack(self.pack, zf.AYAH_COUNTS).problems, [])
        held = json.loads(report.read_bytes())
        self.assertTrue(report.read_bytes().isascii())
        self.assertEqual(held["held"], [{"n": 5, "reason": "not_found", "site_page": 11}, {"n": 6, "reason": "flagged", "site_page": 11}])
        self.assertEqual(held["never_shipped_by_kind"], {"heading": 1, "text": 1, "unlinked": 1})
        passages = (self.book.links / "passages.jsonl").read_bytes()
        self.assertEqual(
            held["surah_level"],
            {"1": {"entries": [2], "entries_sha256": self.book.surah_level_sha256(passages, 1), "cleared_together": True}},
        )

    def test_the_stored_texts_read_back_equal(self):
        self.assertEqual(self.tafsir()[0], 0)
        with sqlite3.connect(str(self.pack / "tafsir.sqlite")) as db:
            rows = db.execute("SELECT number, surah, first_ayah, last_ayah, CAST(text AS BLOB) FROM passage").fetchall()
            book = db.execute("SELECT * FROM book").fetchall()
        db.close()
        self.assertEqual([r[:4] + (bytes(r[4]),) for r in rows], [r[:4] + (r[4].encode("utf-8"),) for r in ROWS])
        self.assertEqual(book, [("Synthetic book " + zf.PHRASE, "Synthetic author", "Synthetic publisher", "Synthetic edition 1", None)])

    def test_the_header(self):
        self.assertEqual(self.tafsir()[0], 0)
        path = self.pack / "tafsir.sqlite"
        data = path.read_bytes()
        self.assertEqual(data[68:72], b"HQPK")
        self.assertEqual(int.from_bytes(data[60:64], "big"), 2)
        self.assertEqual((data[18], data[19]), (1, 1))
        self.assertEqual(int.from_bytes(data[36:40], "big"), 0)
        with sqlite3.connect(path.absolute().as_uri() + "?mode=ro", uri=True) as db:
            strict = db.execute("SELECT name, strict FROM pragma_table_list WHERE schema = 'main' AND name NOT LIKE 'sqlite_%' ORDER BY name").fetchall()
        db.close()
        self.assertEqual(strict, [("book", 1), ("passage", 1)])

    def test_the_manifest(self):
        self.assertEqual(self.tafsir()[0], 0)
        manifest = json.loads((self.pack / "manifest.json").read_bytes())
        self.assertEqual(list(manifest), MANIFEST_KEYS)
        self.assertEqual((manifest["kind"], manifest["format_version"], manifest["riwaya"]), ("tafsir", 2, "hafs"))
        source = manifest["sources"][0]
        self.assertEqual(
            (source["role"], source["registry_row"], source["url"], source["version"], source["fetched_on"]),
            ("tafsir", 18, "https://ziydia.com/book/183", "2020-01-02", "2026-01-05"),
        )
        self.assertEqual(source["file_sha256"], zf.sha256((self.book.extraction / "pages.jsonl").read_bytes()))
        self.assertEqual(manifest["counts"], {"passages": 4})
        table_sha256 = zf.sha256(self.book.path("table.json").read_bytes())
        self.assertEqual(
            [(r["reviewer"], r["date"]) for r in manifest["reviews"]],
            [("Synthetic approver", "2026-01-02"), ("Synthetic reviewer", "2026-01-03"), ("Synthetic reviewer", "2026-01-05")],
        )
        self.assertIn(table_sha256, manifest["reviews"][0]["scope"])
        record_sha256 = zf.sha256(self.book.path("review.json").read_bytes())
        self.assertEqual(
            manifest["reviews"][2]["scope"],
            "review record SHA-256 %s: cleared 0, excluded 0, surah-level entries cleared for 1 surahs (D-186)"
            % record_sha256,
        )

    def test_clearances_and_exclusions_are_bound_in_the_reviews(self):
        self.book.cleared, self.book.excluded = [6], [3]
        self.book.write()
        code, out, _ = self.tafsir()
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 5 surah-level 1", out)
        manifest = json.loads((self.pack / "manifest.json").read_bytes())
        record_sha256 = zf.sha256(self.book.path("review.json").read_bytes())
        self.assertEqual(
            [r["scope"] for r in manifest["reviews"][2:]],
            [
                "review record SHA-256 %s: cleared 1, excluded 0, surah-level entries cleared for 0 surahs (D-186)"
                % record_sha256,
                "review record SHA-256 %s: cleared 0, excluded 1, surah-level entries cleared for 0 surahs (D-186)"
                % record_sha256,
                "review record SHA-256 %s: cleared 0, excluded 0, surah-level entries cleared for 1 surahs (D-186)"
                % record_sha256,
            ],
        )
        with sqlite3.connect(str(self.pack / "tafsir.sqlite")) as db:
            ranges = db.execute("SELECT surah, first_ayah, last_ayah FROM passage ORDER BY number").fetchall()
        db.close()
        self.assertEqual(ranges, [(1, 0, 0), (1, 2, 3), (2, 1, 1), (2, 2, 3), (3, 1, 1)])

    def test_a_surah_level_entry_ships_only_when_the_record_clears_it(self):
        self.book.cleared_surah_level = []
        self.book.write()
        report = self.work / "held.json"
        code, out, _ = self.tafsir(report=report)
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 3 surah-level 0", out)
        held = json.loads(report.read_bytes())
        self.assertIn({"n": 2, "reason": "not_cleared", "site_page": 10}, held["held"])
        self.assertFalse(held["surah_level"]["1"]["cleared_together"])
        self.assertNotIn(b"surah-level opening", (self.pack / "tafsir.sqlite").read_bytes())

    def test_a_single_clearance_ships_a_surah_level_entry_and_an_exclusion_holds_it(self):
        self.book.cleared_surah_level, self.book.cleared = [], [2]
        self.book.write()
        code, out, _ = self.tafsir()
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 4 surah-level 1", out)
        self.book.cleared, self.book.excluded, self.book.cleared_surah_level = [2], [2], [1]
        self.book.write()
        self.book.out = self.work / "out-excluded"
        code, out, _ = self.tafsir()
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 3 surah-level 0", out)

    def test_paragraphs_above_the_rule_never_ship(self):
        above = zf.entry("above_the_rule", 1, [], (12, zf.para(zf.SENTINEL + " above")))
        self.book.entries.insert(2, above)
        self.book.write()
        report = self.work / "held.json"
        code, out, _ = self.tafsir(report=report)
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 4 surah-level 1", out)
        self.assertEqual(json.loads(report.read_bytes())["never_shipped_by_kind"]["above_the_rule"], 1)
        for name in ("tafsir.sqlite", "manifest.json"):
            self.assertNotIn(zf.SENTINEL.encode("ascii"), (self.pack / name).read_bytes())
        self.book.cleared, self.book.out = [3], self.work / "out-cleared"
        self.book.write()
        self.assert_refused("review record: cleared names 3, an entry that never ships")

    def test_a_kind_that_never_ships_never_reaches_the_pack(self):
        self.assertEqual(self.tafsir()[0], 0)
        for name in ("tafsir.sqlite", "manifest.json"):
            self.assertNotIn(zf.SENTINEL.encode("ascii"), (self.pack / name).read_bytes())
        self.assertIn(b"Synthetic last", (self.pack / "tafsir.sqlite").read_bytes())


class TafsirRefusalTest(_Case):
    def test_usage(self):
        code, _, err = self.run_cli("tafsir", *self.book.args(honorifics=None))
        self.assertEqual(code, cli.EX_USAGE)
        self.assertIn("--honorifics", err)

    def test_anything_else_is_printed_by_its_type(self):
        with mock.patch.object(cli, "build_tafsir_pack", side_effect=RuntimeError("Synthetic secret")):
            code, _, err = self.tafsir()
        self.assertEqual(code, cli.EX_SOFTWARE)
        self.assertEqual(err.strip(), "failed: RuntimeError")

    def test_a_missing_or_unapproved_table_or_record(self):
        self.assert_refused("the honorific table cannot be read", honorifics=self.work / "absent.json")
        self.assert_refused("the review record cannot be read", reviews=self.work / "absent.json")
        self.book.table["approved_on"] = None
        self.book.write()
        self.assert_refused("honorific table: approved_on is missing, so the table is not approved")

    def test_another_font_than_the_pinned_tafsir_font(self):
        self.assert_refused("not that of the tafsir font %s" % tafsir_build.TAFSIR_FONT_SHA256, font=AMIRI)

    def test_an_output_inside_a_git_tree_or_an_existing_version(self):
        inside = REPO / "tools" / "packs" / "never-written"
        self.assert_refused("is inside the Git working tree", out=inside)
        self.assertFalse(inside.exists())
        self.assertEqual(self.tafsir()[0], 0)
        code, _, err = self.tafsir()
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("exists; a pack version is never rebuilt in place", err)

    def test_a_report_inside_a_git_tree(self):
        code, _, err = self.tafsir(report=REPO / "held-never-written.json")
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("is inside the Git working tree", err)
        self.assertFalse((REPO / "held-never-written.json").exists())

    def test_a_report_that_exists_or_has_no_folder(self):
        existing = self.work / "held.json"
        existing.write_bytes(b"synthetic earlier report")
        self.assert_refused("exists; a report is never overwritten", report=existing)
        self.assertEqual(existing.read_bytes(), b"synthetic earlier report")
        self.assert_refused("does not exist", report=self.work / "absent" / "held.json")
        self.assertFalse((self.work / "absent").exists())

    def test_a_riwaya_other_than_hafs(self):
        path = self.book.path("tafsir.json")
        description = json.loads(path.read_bytes())
        description["riwaya"] = "warsh"
        path.write_bytes(zf.dumps(description))
        self.assert_refused("tafsir description: riwaya must be hafs")

    def test_a_hash_mismatch(self):
        path = self.book.path("tafsir.json")
        description = json.loads(path.read_bytes())
        description["passages_sha256"] = "0" * 64
        path.write_bytes(zf.dumps(description))
        self.assert_refused("passages.jsonl has SHA-256")

    def test_unknown_markup_or_code_in_a_shipped_paragraph(self):
        for html, expected in (
            (zf.para("<i>Synthetic</i>"), "entry 3 paragraph 1 (site page 10): unknown markup <i>"),
            (zf.para("Synthetic " + zf.code("\u00d7")), "the code U+00D7 at offset 54 is not in the honorific table"),
            (zf.para("Synthetic<sup>1</sup>"), "<sup> at offset 53 belongs to a footnote"),
        ):
            with self.subTest(expected=expected):
                self.book.entries[2] = dict(self.book.entries[2], paragraphs=[(10, html)])
                self.book.write()
                self.assert_refused(expected)

    def test_a_code_point_outside_the_font(self):
        self.book.entries[2] = dict(self.book.entries[2], paragraphs=[(10, zf.para("Synthetic \u2c00"))])
        self.book.write()
        self.assert_refused("1 code points are not in the tafsir font: U+2C00 first at passage 2")

    def test_a_range_outside_its_surah(self):
        self.book.entries[2] = dict(self.book.entries[2], refs=[[3, 5]])
        self.book.write()
        self.assert_refused("entry 3 reaches ayah 5 of surah 1, which has 4")

    def test_no_passage_left(self):
        self.book.excluded = [2, 3, 4, 7, 10]
        self.book.write()
        self.assert_refused("no passage is left to ship")

    def test_a_paragraph_that_is_not_its_pages(self):
        self.book.write()
        passages = self.book.links / "passages.jsonl"
        lines = passages.read_bytes().decode("utf-8").splitlines(keepends=True)
        line = json.loads(lines[2])
        line["paragraphs"][0]["site_page"] = 11
        lines[2] = json.dumps(line, ensure_ascii=False, sort_keys=True) + "\n"
        data = "".join(lines).encode("utf-8")
        passages.write_bytes(data)
        self._retie(data)
        self.assert_refused("entry 3 paragraph 1 (site page 11) is not a paragraph of site page 11 in pages.jsonl (P3)")

    def _retie(self, passages):
        """Ties the hashes again after passages.jsonl was changed by hand."""
        digest = zf.sha256(passages)
        for path in (self.book.links / "report.json", self.book.links / "compare.json"):
            value = json.loads(path.read_bytes())
            value["passages_sha256"] = digest
            path.write_bytes(zf.dumps(value))
        record = json.loads(self.book.path("review.json").read_bytes())
        record["passages_sha256"] = digest
        record["compare_sha256"] = zf.sha256((self.book.links / "compare.json").read_bytes())
        self.book.write_file("review.json", json.dumps(record).encode("ascii"))
        description = json.loads(self.book.path("tafsir.json").read_bytes())
        description["passages_sha256"] = digest
        self.book.write_file("tafsir.json", zf.dumps(description))

    def test_a_stored_text_that_does_not_read_back(self):
        real = tafsir_build.read_tafsir_texts

        def altered(path):
            stored = real(path)
            passages = dict(stored.passages)
            passages[2] = passages[2][:-1]
            return StoredTafsirTexts(stored.book, passages)

        with mock.patch.object(tafsir_build, "read_tafsir_texts", altered):
            self.assert_refused("passage 2: the stored bytes differ from the text written (P4)")

    def test_any_verifier_problem(self):
        report = Report(["synthetic verifier problem"], {"passages": 4}, False)
        with mock.patch.object(tafsir_build, "verify_tafsir_pack", return_value=report):
            self.assert_refused("the built pack fails verification: synthetic verifier problem")


if __name__ == "__main__":
    unittest.main()
