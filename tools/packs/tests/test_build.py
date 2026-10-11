"""The pipeline end to end on the synthetic source, and one refusal per build check."""

import hashlib
import json
import sqlite3
import struct
import unittest
from unittest import mock

import synthetic_source as synthetic
from hqpack import build
from hqpack.build import build_pack
from hqpack.errors import PackError
from hqpack.verify import Report, verify_pack

from tests.build_support import FONT, OTHER_FONT, BuildCase, suras_with, surahs_with_ayah, surahs_with_basmala


class SyntheticBuildTest(BuildCase):
    def setUp(self):
        super().setUp()
        self.result = build_pack(self.write_source(), FONT, self.out)
        self.pack = self.result.directory
        self.manifest = json.loads((self.pack / "manifest.json").read_text(encoding="utf-8"))

    def test_the_pack_sits_at_id_and_version_unsigned(self):
        self.assertEqual(self.pack, self.out / "synthetic-text" / "1")
        self.assertEqual(sorted(p.name for p in self.pack.iterdir()), ["manifest.json", "text.sqlite"])
        self.assertEqual(sorted(p.name for p in self.out.iterdir()), ["synthetic-text"])

    def test_counts(self):
        self.assertEqual(
            self.result.counts,
            {
                "surahs": 3,
                "ayat": 8,
                "words": 21,
                "marks": 5,
                "divisions": {"juz": 2, "hizb": 2, "rub": 8, "page": 4},
                "sajdas": 2,
            },
        )
        self.assertEqual(self.manifest["counts"], self.result.counts)

    def test_the_independent_verifier_accepts_it(self):
        report = verify_pack(self.pack)
        self.assertEqual(report.problems, [])
        self.assertFalse(report.signed)

    def test_every_stored_text_is_the_source_text_byte_for_byte(self):
        with sqlite3.connect(self.pack.joinpath("text.sqlite").as_uri() + "?mode=ro&immutable=1", uri=True) as db:
            ayat = db.execute("SELECT surah, number, CAST(text AS BLOB) FROM ayah ORDER BY surah, number").fetchall()
            surahs = db.execute("SELECT number, CAST(basmala AS BLOB) FROM surah ORDER BY number").fetchall()
        expected = [
            (s, a, text.encode("utf-8"))
            for s, (_, _, texts) in enumerate(synthetic.SYNTHETIC_SURAHS, 1)
            for a, text in enumerate(texts, 1)
        ]
        self.assertEqual(ayat, expected)
        self.assertEqual(
            surahs,
            [
                (s, None if basmala is None else basmala.encode("utf-8"))
                for s, (_, basmala, _) in enumerate(synthetic.SYNTHETIC_SURAHS, 1)
            ],
        )

    def test_surah_digest_matches_an_independent_computation(self):
        _, basmala, ayat = synthetic.SYNTHETIC_SURAHS[0]
        h = hashlib.sha256()
        for number, text in [(0, basmala)] + list(enumerate(ayat, 1)):
            data = text.encode("utf-8")
            h.update(struct.pack(">II", number, len(data)) + data)
        self.assertEqual(self.manifest["surah_sha256"]["1"], h.hexdigest())

    def test_sources_carry_options_notice_and_hashes(self):
        text, edition_map = self.manifest["sources"]
        self.assertEqual(text["options"], {"marks": "true", "sajdah": "true", "rub": "false", "outType": "xml"})
        self.assertEqual(list(text["options"]), ["marks", "sajdah", "rub", "outType"])
        self.assertIsNone(edition_map["options"])
        self.assertEqual(text["licence"]["notice"], synthetic.TEXT_NOTICE)
        self.assertEqual(edition_map["licence"]["notice"], synthetic.METADATA_NOTICE)
        self.assertEqual(text["file_sha256"], hashlib.sha256(synthetic.synthetic_text_xml()).hexdigest())

    def test_font_and_file_hashes(self):
        self.assertEqual(
            self.manifest["font"],
            {"family": "Amiri Quran", "version": "1.003", "sha256": hashlib.sha256(FONT.read_bytes()).hexdigest()},
        )
        data = (self.pack / "text.sqlite").read_bytes()
        self.assertEqual(self.manifest["files"], [{"name": "text.sqlite", "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}])

    def test_revelation_facts_come_from_the_metadata(self):
        with sqlite3.connect(self.pack.joinpath("text.sqlite").as_uri() + "?mode=ro&immutable=1", uri=True) as db:
            rows = db.execute("SELECT number, revelation_place, revelation_order FROM surah ORDER BY number").fetchall()
        self.assertEqual(rows, [(1, "makki", 2), (2, "madani", 1), (3, "makki", 3)])

    def test_hizbs_are_every_fourth_quarter(self):
        with sqlite3.connect(self.pack.joinpath("text.sqlite").as_uri() + "?mode=ro&immutable=1", uri=True) as db:
            rows = db.execute("SELECT number, surah, ayah FROM division WHERE kind = 'hizb' ORDER BY number").fetchall()
        self.assertEqual(rows, [(1, 1, 1), (2, 2, 1)])

    def test_a_version_is_never_rebuilt(self):
        with self.assertRaisesRegex(PackError, "never rebuilt in place"):
            build_pack(self.write_source(), FONT, self.out)


class RefusalTest(BuildCase):
    def assert_refused(self, pattern, config=None, font=FONT):
        config = config or self.write_source()
        with self.assertRaises(PackError) as caught:
            build_pack(config, font, self.out)
        message = str(caught.exception)
        self.assertRegex(message, pattern)
        self.assert_safe_message(message)
        self.assert_out_empty()

    def text(self, **kwargs):
        return self.write_source(text_xml=synthetic.synthetic_text_xml(**kwargs))

    def metadata(self, **kwargs):
        return self.write_source(metadata_xml=synthetic.synthetic_metadata_xml(**kwargs))

    def test_a_source_file_with_another_hash(self):
        config = self.write_source()
        (self.source / synthetic.TEXT_FILE).write_bytes(synthetic.synthetic_text_xml() + b"\n")
        self.assert_refused(r"sources\.text: the file has SHA-256 [0-9a-f]{64}, the description expects", config)

    def test_a_hafs_pack_needs_the_kfgqpc_comparison(self):
        self.assert_refused("KFGQPC", self.write_source(riwaya="hafs", id="base-hafs-tanzil"))

    def test_a_riwaya_without_profile(self):
        self.assert_refused("riwaya warsh has no profile", self.write_source(riwaya="warsh", id="base-warsh"))

    def test_a_font_other_than_the_text_pair(self):
        self.assert_refused("not Amiri Quran", font=OTHER_FONT)

    def test_a_notice_without_the_source_version(self):
        self.assert_refused("does not name Version 1", self.text(notice="\nSynthetic notice\nVersion 2\n"))

    def test_a_text_without_its_notice_comment(self):
        config = self.write_source(text_xml=synthetic.synthetic_text_xml().split(b"\n<!--")[0] + b"\n")
        self.assert_refused("0 comments outside the root element", config)

    def test_a_surah_count_other_than_the_profile(self):
        self.assert_refused("has 2 surahs, not 3", self.text(surahs=synthetic.SYNTHETIC_SURAHS[:2]))

    def test_metadata_ayah_count_differs(self):
        self.assert_refused("surah 1: the metadata gives 5 ayat, the text file has 4", self.metadata(suras=suras_with(1, ayas=5)))

    def test_metadata_start_differs(self):
        self.assert_refused("surah 2: the metadata starts it after 3 ayat", self.metadata(suras=suras_with(2, start=3)))

    def test_a_basmala_where_the_profile_has_none(self):
        self.assert_refused("surah 2 has a separate basmala", self.text(surahs=surahs_with_basmala(2, "Synthetic opening line")))

    def test_a_missing_basmala(self):
        self.assert_refused("surah 3 lacks a separate basmala", self.text(surahs=surahs_with_basmala(3, None)))

    def test_an_unknown_revelation_type(self):
        self.assert_refused("surah 2: the metadata type is not one of", self.metadata(suras=suras_with(2, type="Synthetic")))

    def test_revelation_orders_that_are_not_a_permutation(self):
        self.assert_refused("revelation orders", self.metadata(suras=suras_with(3, order=2)))

    def test_quarters_that_make_no_whole_hizb(self):
        self.assert_refused("7 quarters", self.metadata(quarters=synthetic.SYNTHETIC_QUARTERS[:7]))

    def test_a_division_count_other_than_the_profile(self):
        self.assert_refused("3 page units, not 4", self.metadata(pages=synthetic.SYNTHETIC_PAGES[:3]))

    def test_a_division_outside_the_text(self):
        self.assert_refused("page 4 refers to 3:2", self.metadata(pages=((1, 1), (1, 4), (2, 2), (3, 2))))

    def test_divisions_out_of_order(self):
        self.assert_refused("page 3 at 1:2 does not start after page 2", self.metadata(pages=((1, 1), (1, 4), (1, 2), (3, 1))))

    def test_a_first_unit_not_at_the_start(self):
        self.assert_refused("juz 1 does not start at 1:1", self.metadata(juzs=((1, 2), (2, 1))))

    def test_a_ruku_outside_the_text(self):
        self.assert_refused("ruku 3 refers to 4:1", self.metadata(rukus=((1, 1), (2, 1), (4, 1))))

    def test_a_sajda_outside_the_text(self):
        self.assert_refused("sajda 2 refers to 2:4", self.metadata(sajdas=((1, 2, "recommended"), (2, 4, "obligatory"))))

    def test_sajda_signs_that_disagree_with_the_metadata(self):
        config = self.metadata(sajdas=((1, 1, "recommended"), (2, 3, "obligatory")))
        self.assert_refused(r"ayat 1:2 hold U\+06E9 but are not sajdas", config)

    def test_a_sign_the_options_exclude(self):
        config = self.write_source(
            text_xml=synthetic.synthetic_text_xml(surahs=surahs_with_ayah(3, 1, "Synthetic last \u06de ayah")),
            mark_table=b'{"code_points": ["U+06D6", "U+06D7", "U+06DA", "U+06DE", "U+06E9"]}\n',
        )
        self.assert_refused(r"U\+06DE", config)

    def test_a_separator_other_than_space(self):
        self.assert_refused(r"ayah 3:1 .*U\+00A0", self.text(surahs=surahs_with_ayah(3, 1, "Synthetic\u00a0last ayah")))

    def test_a_mark_outside_the_mark_table(self):
        self.assert_refused(r"ayah 3:1 mark 1 holds U\+06DB", self.text(surahs=surahs_with_ayah(3, 1, "Synthetic \u06db last")))

    def test_a_code_point_the_font_lacks(self):
        self.assert_refused(r"the font lacks U\+00E9 \(first in ayah 3:1\)", self.text(surahs=surahs_with_ayah(3, 1, "Synth\u00e9tic last")))

    def test_a_leading_byte_order_mark(self):
        self.assert_refused(r"U\+FEFF", self.text(surahs=surahs_with_ayah(3, 1, "\ufeffSynthetic last ayah")))

    def test_stored_bytes_that_differ_from_the_source(self):
        real = build.database.read_stored_texts

        def flipped(path):
            stored = real(path)
            stored.ayat[(2, 1)] = b"X" + stored.ayat[(2, 1)][1:]
            return stored

        with mock.patch.object(build.database, "read_stored_texts", flipped):
            self.assert_refused("ayah 2:1: the stored bytes differ from the source bytes")

    def test_a_pack_the_verifier_refuses_is_not_kept(self):
        refused = Report(problems=["synthetic problem"], counts=None, signed=False)
        with mock.patch.object(build, "verify_pack", return_value=refused):
            self.assert_refused("fails verification: synthetic problem")


if __name__ == "__main__":
    unittest.main()
