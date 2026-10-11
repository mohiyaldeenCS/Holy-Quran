from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from collections import namedtuple
from pathlib import Path

from hqpack.verify import verify_pack
from tests import pack_factory as factory

Font = namedtuple("Font", "family version sha256 code_points")

# A stable part of the problem each fault must produce.
EXPECTED = {
    "flipped_byte": "text.sqlite: SHA-256 differs from files[0].sha256",
    "wrong_surah_hash": "surah 1: digest differs from surah_sha256",
    "wrong_counts": "counts.ayat is 9; the ayah table holds 8",
    "leading_bom": "ayah 1:1 begins with U+FEFF",
    "wal_header": "header byte 18 is 2",
    "wrong_application_id": "application_id is 1213288524",
    "wrong_user_version": "user_version is 2, not 1",
    "unsupported_format_version": "manifest.format_version is not 1",
    "path_in_file_name": "manifest.files[0].name is not a bare file name",
    "missing_file": "text.sqlite is missing",
    "wrong_file_size": "files[0].bytes is",
    "overlapping_spans": "ayah 1:1: word 2 span 8..14 overlaps",
    "non_strict_schema": "table sajda is not STRICT",
    "mark_overlaps_word": "ayah 1:2: mark 1 span 10..13 overlaps",
    "wrong_after_word": "ayah 1:2: mark 1 has after_word 3; 2 words",
    "wrong_mark_count": "counts.marks is",
    "extra_file": "unexpected entry notes.txt",
    "wrong_directory": "manifest.id is not the name of the directory",
    "unknown_field": "manifest.font has unknown field style",
    "duplicate_key": "manifest.json repeats a key",
    "empty_options": "manifest.sources[0].options is empty",
    "licence_without_reference":
        "manifest.sources[1].licence has neither text nor permission_ref",
    "bool_for_int": "manifest.counts.sajdas is not an integer",
    "nbsp": "ayah 3:1: U+00A0 at offset 9 is a separator other than U+0020",
    "word_as_mark": "ayah 1:1: mark 1 span 0..9 holds the letter U+0053",
    "division_missing_ayah": "page 4 refers to 3:9, not an ayah of the pack",
    "freelist": "free pages: the build did not end with VACUUM",
    "extra_index": "sqlite_schema holds the index word_by_start",
    "extra_trigger": "sqlite_schema holds the trigger sajda_guard",
    "short_signature": "manifest.json.sig has 63 bytes, not 64",
    "manifest_bom": "manifest.json begins with a byte order mark",
    "manifest_string_bom": "manifest.edition begins with U+FEFF",
    "nan_value": "manifest.json holds NaN or Infinity",
}

# Tokens of the synthetic texts that no message may hold: capitalised or
# non-ASCII ones, besides every whole value.
LEAK_TOKENS = sorted({
    token
    for value in factory.text_values()
    for token in value.split(" ")
    if token and (not token.isascii() or not token.islower())
})


class VerifyTest(unittest.TestCase):
    def setUp(self):
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name) / "with space"

    def tearDown(self):
        self._temporary.cleanup()

    def pack(self, fault=None, **kwargs):
        return factory.write_pack(
            self.root / (fault or "clean"), fault=fault, **kwargs)

    def assertClean(self, report):
        self.assertEqual(report.problems, [])

    def test_clean_pack_verifies(self):
        report = verify_pack(self.pack())
        self.assertClean(report)
        self.assertFalse(report.signed)
        self.assertEqual(report.counts["surahs"], 3)
        self.assertEqual(report.counts["ayat"], 8)
        self.assertEqual(report.counts["divisions"]["rub"], 8)

    def test_counts_words_and_marks_by_letters(self):
        counts = verify_pack(self.pack()).counts
        self.assertEqual(counts["words"], 23)
        self.assertEqual(counts["marks"], 4)

    def test_signed_with_a_signature_of_64_bytes(self):
        directory = self.pack()
        (directory / "manifest.json.sig").write_bytes(bytes(64))
        report = verify_pack(directory)
        self.assertClean(report)
        self.assertTrue(report.signed)

    def test_every_fault_is_found(self):
        self.assertEqual(sorted(EXPECTED), sorted(factory.FAULTS))
        for fault, expected in EXPECTED.items():
            with self.subTest(fault=fault):
                problems = verify_pack(self.pack(fault)).problems
                self.assertTrue(
                    any(expected in problem for problem in problems),
                    "%s not in %r" % (expected, problems))

    def test_problems_are_ascii_and_hold_no_text(self):
        values = factory.text_values() + LEAK_TOKENS + [factory.PHRASE]
        for fault in factory.FAULTS:
            with self.subTest(fault=fault):
                for problem in verify_pack(self.pack(fault)).problems:
                    self.assertTrue(problem.isascii(), problem)
                    for value in values:
                        self.assertNotIn(value, problem)

    def test_manifest_that_does_not_parse_has_no_counts(self):
        report = verify_pack(self.pack("unknown_field"))
        self.assertIsNone(report.counts)

    def test_mark_table(self):
        directory = self.pack()
        self.assertClean(verify_pack(directory, factory.MARK_CODE_POINTS))
        problems = verify_pack(
            directory, factory.MARK_CODE_POINTS - {0x06DA}).problems
        self.assertEqual(
            problems,
            ["U+06DA is in a mark but not in the mark table; first at "
             "ayah 1:3"])

    def test_font(self):
        directory = self.pack()
        good = Font(factory.FONT_FAMILY, factory.FONT_VERSION,
                    factory.FONT_SHA256, factory.code_points())
        self.assertClean(verify_pack(directory, font=good))
        wrong = Font("Synthetic Family", "9.999", "0" * 64,
                     factory.code_points() - {0x1F600, 0x0640})
        problems = verify_pack(directory, font=wrong).problems
        for expected in (
            "font.sha256 is not the SHA-256 of the font file",
            "font.family is not the family of the font file",
            "font.version is not the version of the font file",
            "U+0640 is not in the font; first at ayah 2:3",
            "U+1F600 is not in the font; first at ayah 2:2",
            "2 code points of the text are not in the font",
        ):
            self.assertIn(expected, problems)

    def test_font_covers_basmala(self):
        points = factory.code_points(
            (factory.Surah("Synthetic name", ("Synthetic ayah",)),))
        surahs = (factory.Surah("Synthetic name", ("Synthetic ayah",),
                                basmala="Synthetic q"),)
        directory = self.pack(surahs=surahs, divisions=(), sajdas=())
        font = Font(factory.FONT_FAMILY, factory.FONT_VERSION,
                    factory.FONT_SHA256, points)
        self.assertIn("U+0071 is not in the font; first at surah 1 basmala",
                      verify_pack(directory, font=font).problems)

    def test_manifest_rules(self):
        cases = (
            (lambda m: m["changelog"][0].update(date="2026-02-30"),
             "manifest.changelog[0].date is not a calendar date"),
            (lambda m: m["reviews"][0].update(date="2026-1-01"),
             "manifest.reviews[0].date is not YYYY-MM-DD"),
            (lambda m: m.update(riwaya="Hafs"),
             "manifest.riwaya is not of the form"),
            (lambda m: m.update(riwaya=None),
             "manifest.riwaya of a text pack is null"),
            (lambda m: m.update(kind="tafsir"),
             "manifest.kind is not a known kind"),
            (lambda m: m.update(version=0), "manifest.version is not positive"),
            (lambda m: m["font"].update(sha256="A" * 64),
             "manifest.font.sha256 is not lowercase hex SHA-256"),
            (lambda m: m["sources"].pop(0),
             "manifest.sources of a text pack has no text source"),
            (lambda m: m.update(sources=[]), "manifest.sources is empty"),
            (lambda m: m["sources"][0].update(trust_grade="D"),
             "manifest.sources[0].trust_grade is not A, B or C"),
            (lambda m: m["sources"][0].update(role="search"),
             "manifest.sources[0].role is not text or edition_map"),
            (lambda m: m["sources"][0]["options"].update(nested={}),
             "manifest.sources[0].options.nested is not a string"),
            (lambda m: m["sources"][0]["options"].update({"": 1}),
             "manifest.sources[0].options has an empty option name"),
            (lambda m: m["sources"][1]["licence"].update(allows_export=1),
             "manifest.sources[1].licence.allows_export is not a boolean"),
            (lambda m: m["files"].append(dict(m["files"][0])),
             "manifest.files of a text pack is not exactly text.sqlite"),
            (lambda m: m["counts"].update(words=-1),
             "manifest.counts.words is negative"),
            (lambda m: m["counts"].update(ayat=8.0),
             "manifest.counts.ayat is not an integer"),
            (lambda m: m["counts"]["divisions"].pop("rub"),
             "manifest.counts.divisions lacks field rub"),
            (lambda m: m["surah_sha256"].pop("2"),
             "manifest.surah_sha256 lacks field 2"),
            (lambda m: m["surah_sha256"].update({"4": "0" * 64}),
             "manifest.surah_sha256 has unknown field 4"),
            (lambda m: m.pop("reviews"), "manifest lacks field reviews"),
            (lambda m: m.update(format="other"),
             "manifest.format is not holyquran-pack"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                directory = self.pack()
                path = directory / "manifest.json"
                manifest = json.loads(path.read_bytes())
                change(manifest)
                path.write_text(json.dumps(manifest), encoding="utf-8")
                report = verify_pack(directory)
                self.assertTrue(
                    any(expected in p for p in report.problems),
                    "%s not in %r" % (expected, report.problems))
                self.assertIsNone(report.counts)
                shutil.rmtree(self.root / "clean")

    def test_divisions_start_in_order(self):
        divisions = (("juz", 1, 2, 1), ("juz", 2, 1, 1))
        problems = verify_pack(self.pack(divisions=divisions)).problems
        self.assertEqual(problems, ["juz 2 does not start after juz 1"])

    def test_counts_name_the_table(self):
        problems = verify_pack(self.pack("wrong_counts")).problems
        self.assertEqual(problems, [
            "counts.ayat is 9; the ayah table holds 8",
            "counts.ayat is 9; surah.ayah_count sums to 8",
        ])

    def test_missing_directory(self):
        report = verify_pack(self.root / "absent" / "1")
        self.assertEqual(report.problems, ["the pack directory does not exist"])
        self.assertIsNone(report.counts)

    def test_stored_spans_must_equal_the_text(self):
        problems = verify_pack(self.pack("word_as_mark")).problems
        self.assertIn(
            "ayah 1:1: word 1 is stored as 10..14, the text gives 0..9",
            problems)
        self.assertIn(
            "ayah 1:1: mark 1 is stored as 0..9 after word 0; the text has "
            "no mark 1", problems)


if __name__ == "__main__":
    unittest.main()
