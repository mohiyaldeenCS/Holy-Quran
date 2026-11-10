"""The independent tafsir verifier on synthetic packs: clean, every fault, and a pack from the writer."""

from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
import unittest
from collections import namedtuple
from pathlib import Path

from hqpack.manifest import build_tafsir_manifest, encode_manifest, source_entry
from hqpack.tafsir_database import SURAH_LEVEL, BookFacts, PassageRow, write_tafsir_database
from hqpack.verify_tafsir import verify_tafsir_pack
from tests import pack_factory
from tests import tafsir_pack_factory as factory

Font = namedtuple("Font", "family version sha256 code_points")

# A stable part of the problem each fault must produce.
EXPECTED = {
    "flipped_byte": "tafsir.sqlite: SHA-256 differs from files[0].sha256",
    "wrong_counts": "counts.passages is 6; the passage table holds 5",
    "wal_header": "tafsir.sqlite: header byte 18 is 2",
    "wrong_application_id": "tafsir.sqlite: application_id is 1213288524",
    "wrong_user_version": "tafsir.sqlite: user_version is 1, not 2",
    "format_version_1": "manifest.format_version is not 2",
    "text_kind": "manifest.kind is not tafsir",
    "text_key": "manifest has unknown field edition",
    "missing_key": "manifest lacks field reviews",
    "wrong_source_role": "manifest.sources[0].role is not tafsir",
    "text_file_name": "manifest.files of a tafsir pack is not exactly tafsir.sqlite",
    "zero_passages_count": "manifest.counts.passages is not positive",
    "null_riwaya": "manifest.riwaya of a tafsir pack is null",
    "duplicate_key": "manifest.json repeats a key",
    "manifest_bom": "manifest.json begins with a byte order mark",
    "missing_file": "tafsir.sqlite is missing",
    "wrong_file_size": "files[0].bytes is",
    "extra_file": "the pack directory holds an unexpected entry notes.txt",
    "wrong_directory": "manifest.id is not the name of the directory",
    "short_signature": "manifest.json.sig has 63 bytes, not 64",
    "non_strict_schema": "tafsir.sqlite: table passage is not STRICT",
    "extra_column": "tafsir.sqlite: table book has 6 columns, not 5",
    "extra_table": "tafsir.sqlite: the tables are book, passage, note, not book, passage",
    "no_check": "tafsir.sqlite: table passage is not created as format 2 gives it",
    "extra_index": "sqlite_schema holds the index passage_by_surah",
    "extra_trigger": "sqlite_schema holds the trigger book_guard",
    "freelist": "free pages: the build did not end with VACUUM",
    "two_books": "the book table holds 2 rows, not 1",
    "no_book": "the book table holds 0 rows, not 1",
    "gap_in_numbering": "passage 3 is numbered 4",
    "out_of_order": "passage 4 does not follow passage 3 in mushaf order",
    "overlap": "passages 2 and 3 overlap",
    "past_the_surah": "passage 3 reaches ayah 5 of surah 1, which has 4",
    "reversed_range": "passage 3: range 4..3 of surah 1 is reversed",
    "below_ayah_one": "passage 5: range 0..1 of surah 3 is neither surah-level (0..0) nor from ayah 1",
    "unknown_surah": "passage 5: surah 4 is not a surah of the ayah counts (1 to 3)",
    "two_surah_level": "surah 1 has more than one surah-level passage (passages 1 and 2)",
    "surah_level_after_ayah": "passage 2 does not follow passage 1 in mushaf order",
    "leading_bom": "passage 1 holds U+FEFF at code point 0",
    "inner_bom": "passage 2 holds U+FEFF at code point 9",
    "bad_utf8": "passage 2 is not UTF-8 (byte",
    "empty_text": "passage 2 is empty",
    "empty_fact": "book.publisher is empty",
    "bad_utf8_fact": "book.title is not UTF-8 (byte 0)",
}

LEAK_TOKENS = sorted({
    token
    for value in factory.text_values()
    for token in value.split()
    if token and (not token.isascii() or not token.islower())
})


class _Case(unittest.TestCase):
    def setUp(self):
        self._temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self._temporary.cleanup)
        self.root = Path(self._temporary.name) / "with space"

    def pack(self, fault=None, **kwargs):
        return factory.write_pack(self.root / (fault or "clean"), fault=fault, **kwargs)

    def verify(self, directory, counts=None, font=None):
        return verify_tafsir_pack(directory, factory.AYAH_COUNTS if counts is None else counts, font)


class VerifyTafsirTest(_Case):
    def test_clean_pack_verifies_with_its_surah_level_passages(self):
        report = self.verify(self.pack())
        self.assertEqual(report.problems, [])
        self.assertEqual(report.counts, {"passages": 5})
        self.assertFalse(report.signed)

    def test_signed_with_a_signature_of_64_bytes(self):
        directory = self.pack()
        (directory / "manifest.json.sig").write_bytes(bytes(64))
        report = self.verify(directory)
        self.assertEqual(report.problems, [])
        self.assertTrue(report.signed)

    def test_every_fault_is_found(self):
        self.assertEqual(sorted(EXPECTED), sorted(factory.FAULTS))
        for fault, expected in EXPECTED.items():
            with self.subTest(fault=fault):
                problems = self.verify(self.pack(fault)).problems
                self.assertTrue(any(expected in p for p in problems), "%s not in %r" % (expected, problems))

    def test_problems_are_ascii_and_hold_no_text(self):
        values = factory.text_values() + LEAK_TOKENS + [factory.PHRASE]
        for fault in factory.FAULTS:
            with self.subTest(fault=fault):
                for problem in self.verify(self.pack(fault)).problems:
                    self.assertTrue(problem.isascii(), problem)
                    for value in values:
                        self.assertNotIn(value, problem)

    def test_ranges_are_checked_against_the_counts_given(self):
        directory = self.pack()
        problems = self.verify(directory, counts={1: 3, 2: 3}).problems
        self.assertEqual(
            problems,
            ["passage 3 reaches ayah 4 of surah 1, which has 3"],
        )
        problems = self.verify(directory, counts={1: 4}).problems
        self.assertIn("passage 4: surah 2 is not a surah of the ayah counts (1 to 1)", problems)

    def test_a_surah_level_passage_alone_in_its_surah(self):
        passages = ((1, 3, 0, 0, "Synthetic surah-level only"),)
        self.assertEqual(self.verify(self.pack(passages=passages)).problems, [])

    def test_font_coverage_with_the_two_exempt_code_points(self):
        passages = factory.PASSAGES[:4] + ((5, 2, 2, 3, "Synthetic\u2063 1 thin\u2009space"),)
        directory = self.pack(passages=passages)
        font = Font("Synthetic", "1", "0" * 64, factory.code_points(passages=passages) - {0x2063, 0x2009})
        self.assertEqual(self.verify(directory, font=font).problems, [])
        lacking = Font("Synthetic", "1", "0" * 64, font.code_points - {0xFDFA, 0x0646})
        self.assertEqual(
            self.verify(directory, font=lacking).problems,
            [
                "U+0646 is not in the font; first at book.title",
                "U+FDFA is not in the font; first at passage 3",
                "2 code points of the text are not in the font",
            ],
        )

    def test_a_text_pack_is_not_a_tafsir_pack(self):
        directory = pack_factory.write_pack(self.root / "text")
        report = self.verify(directory)
        self.assertIn("manifest.format_version is not 2, the format of a tafsir pack", report.problems)
        self.assertIsNone(report.counts)

    def test_missing_directory(self):
        report = self.verify(self.root / "absent" / "1")
        self.assertEqual(report.problems, ["the pack directory does not exist"])

    def test_manifest_rules(self):
        cases = (
            (lambda m: m.update(font={}), "manifest has unknown field font"),
            (lambda m: m.update(surah_sha256={}), "manifest has unknown field surah_sha256"),
            (lambda m: m["counts"].update(surahs=1), "manifest.counts has unknown field surahs"),
            (lambda m: m["counts"].update(passages=True), "manifest.counts.passages is not an integer"),
            (lambda m: m.update(sources=[]), "manifest.sources is empty"),
            (lambda m: m["sources"][0]["licence"].update(permission_ref=None),
             "manifest.sources[0].licence has neither text nor permission_ref"),
            (lambda m: m["changelog"][0].update(date="2026-02-30"), "manifest.changelog[0].date is not a calendar date"),
            (lambda m: m["files"][0].update(sha256="A" * 64), "manifest.files[0].sha256 is not lowercase hex SHA-256"),
            (lambda m: m.update(riwaya="Hafs"), "manifest.riwaya is not of the form"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                directory = self.pack()
                path = directory / "manifest.json"
                manifest = json.loads(path.read_bytes())
                change(manifest)
                path.write_text(json.dumps(manifest), encoding="utf-8")
                report = self.verify(directory)
                self.assertTrue(any(expected in p for p in report.problems), "%s not in %r" % (expected, report.problems))
                self.assertIsNone(report.counts)
                shutil.rmtree(self.root / "clean")


class WriterAgreesTest(_Case):
    """A pack from the pipeline's own writers passes the independent verifier."""

    def test_a_pack_from_the_writer_verifies(self):
        directory = self.root / "synthetic-tafsir" / "1"
        directory.mkdir(parents=True)
        path = directory / "tafsir.sqlite"
        title, author, publisher, edition, editor = factory.BOOK
        write_tafsir_database(
            path,
            BookFacts(title, author, publisher, edition, editor),
            [PassageRow(*row) for row in factory.PASSAGES],
        )
        self.assertEqual(factory.PASSAGES[0][2:4], (SURAH_LEVEL, SURAH_LEVEL))
        data = path.read_bytes()
        source = source_entry(
            role="tafsir",
            registry_row=18,
            name="Synthetic tafsir source",
            publisher="Synthetic publisher",
            url="https://example.invalid/synthetic/book/1",
            version="2026-01-01",
            fetched_on="2026-01-01",
            file_sha256="3" * 64,
            trust_grade="B",
            options=None,
            licence={"text": None, "permission_ref": "Synthetic permission", "notice": None, "allows_export": False},
        )
        manifest = build_tafsir_manifest(
            pack_id="synthetic-tafsir",
            version=1,
            changelog=[{"version": 1, "date": "2026-01-01", "summary": "Synthetic"}],
            riwaya="hafs",
            sources=[source],
            tafsir_sha256=hashlib.sha256(data).hexdigest(),
            tafsir_bytes=len(data),
            passages=len(factory.PASSAGES),
            reviews=[],
        )
        (directory / "manifest.json").write_bytes(encode_manifest(manifest))
        report = self.verify(directory)
        self.assertEqual(report.problems, [])
        self.assertEqual(report.counts, {"passages": 5})


if __name__ == "__main__":
    unittest.main()
