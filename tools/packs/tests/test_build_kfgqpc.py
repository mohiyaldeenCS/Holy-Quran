"""The KFGQPC text path end to end on the synthetic KFGQPC-shaped source, and
one refusal per check it adds (D-195, D-198)."""

import hashlib
import json
import sqlite3
from contextlib import closing
from unittest import mock

import synthetic_source as synthetic
from hqpack import build
from hqpack.build import build_pack
from hqpack.errors import PackError
from hqpack.kfgqpc import FONT_FILE_NAME
from hqpack.known_differences import presentation, read_table
from hqpack.verify import verify_pack

from tests.build_support import BuildCase, hafs_shaped_profiles, suras_with, synthetic_kfgqpc_font

NBSP = "\u00a0"
PAUSE = "\u06d6"
QUARTER_SIGN = "\u06de"
SAJDA = "\u06e9"


def kfgqpc_entries(surahs=synthetic.SYNTHETIC_KFGQPC_SURAHS):
    return synthetic.synthetic_kfgqpc_entries(surahs)


def with_text(surah, ayah, change):
    """The synthetic KFGQPC entries, the aya_text of `surah:ayah` passed through `change`."""
    entries = kfgqpc_entries()
    for entry in entries:
        if (entry["sura_no"], entry["aya_no"]) == (surah, ayah):
            entry["aya_text"] = change(entry["aya_text"])
    return entries


class KfgqpcBuildCase(BuildCase):
    def setUp(self):
        super().setUp()
        self.font = self.work / FONT_FILE_NAME
        self.font.write_bytes(synthetic_kfgqpc_font())
        self.table = self.write_table()

    def write_kfgqpc_source(self, entries=None, **overrides):
        data = None if entries is None else synthetic.synthetic_kfgqpc_json(entries)
        return synthetic.write_synthetic_kfgqpc_source(self.source, kfgqpc_json=data, **overrides)

    def build(self, config=None, **kwargs):
        kwargs.setdefault("table", self.table)
        return build_pack(config or self.write_kfgqpc_source(), self.font, self.out, **kwargs)

    def assert_refused(self, pattern, config=None, **kwargs):
        with self.assertRaises(PackError) as caught:
            self.build(config, **kwargs)
        message = str(caught.exception)
        self.assertRegex(message, pattern)
        self.assert_safe_message(message)
        self.assert_out_empty()
        return message


class SyntheticKfgqpcBuildTest(KfgqpcBuildCase):
    def setUp(self):
        super().setUp()
        self.result = self.build()
        self.pack = self.result.directory
        self.manifest = json.loads((self.pack / "manifest.json").read_text(encoding="utf-8"))

    def query(self, sql):
        uri = self.pack.joinpath("text.sqlite").as_uri() + "?mode=ro&immutable=1"
        with closing(sqlite3.connect(uri, uri=True)) as db:
            return db.execute(sql).fetchall()

    def test_the_pack_is_of_format_3(self):
        self.assertEqual(self.pack, self.out / "synthetic-kfgqpc-text" / "1")
        self.assertEqual(self.manifest["format_version"], 3)
        self.assertEqual(self.query("PRAGMA user_version"), [(3,)])

    def test_counts(self):
        self.assertEqual(
            self.result.counts,
            {
                "surahs": 3,
                "ayat": 8,
                "words": 21,
                "marks": 5,
                "presentations": 13,
                "divisions": {"juz": 2, "hizb": 2, "rub": 8, "page": 4},
                "sajdas": 2,
            },
        )
        self.assertEqual(self.manifest["counts"], self.result.counts)

    def test_the_verifier_accepts_it_with_the_presentation_rules_only(self):
        rules = presentation(read_table(self.table.read_bytes()))
        self.assertEqual(verify_pack(self.pack, presentation=rules).problems, [])
        self.assertEqual(len(verify_pack(self.pack).problems), 1)

    def test_every_ayah_is_stored_as_published(self):
        stored = self.query("SELECT CAST(text AS BLOB) FROM ayah ORDER BY surah, number")
        self.assertEqual(
            [bytes(text) for (text,) in stored],
            [entry["aya_text"].encode("utf-8") for entry in kfgqpc_entries()],
        )

    def test_the_basmala_is_the_first_ayah_between_its_presentation_spans(self):
        first = synthetic.SYNTHETIC_KFGQPC_SURAHS[0][2][0].encode("utf-8")
        rows = self.query("SELECT number, CAST(basmala AS BLOB) FROM surah ORDER BY number")
        self.assertEqual(
            [(n, None if b is None else bytes(b)) for n, b in rows],
            [(1, first), (2, None), (3, first)],
        )

    def test_the_presentation_rows(self):
        self.assertEqual(
            self.query("SELECT * FROM presentation WHERE surah = 1 AND ayah < 3 ORDER BY ayah, number"),
            [(1, 1, 1, 3, 18, 20), (1, 2, 1, 0, 0, 2), (1, 2, 2, 2, 17, 19)],
        )

    def test_a_joined_mark_is_cut_from_its_word(self):
        self.assertEqual(
            self.query("SELECT number, start_offset, end_offset FROM word WHERE surah = 1 AND ayah = 2"),
            [(1, 2, 11), (2, 13, 16)],
        )
        self.assertEqual(
            self.query(
                "SELECT number, after_word, start_offset, end_offset FROM mark WHERE surah = 1 AND ayah = 2"
            ),
            [(1, 1, 11, 12), (2, 2, 16, 17)],
        )

    def test_the_manifest_names_the_kfgqpc_file_as_the_text_source(self):
        text, edition_map = self.manifest["sources"]
        self.assertEqual(
            (text["role"], text["registry_row"], text["options"], text["licence"]["notice"]),
            ("text", 2, None, None),
        )
        self.assertEqual(
            text["file_sha256"],
            hashlib.sha256((self.source / synthetic.KFGQPC_FILE).read_bytes()).hexdigest(),
        )
        self.assertEqual((edition_map["role"], edition_map["registry_row"]), ("edition_map", 4))
        self.assertEqual(self.manifest["font"]["family"], "Synthetic KFGQPC")


class KfgqpcRefusalTest(KfgqpcBuildCase):
    def test_without_the_table(self):
        self.assert_refused(r"give the table \(--table\)", table=None)

    def test_with_a_kfgqpc_witness(self):
        self.assert_refused(
            r"it takes no KFGQPC witness \(--kfgqpc\)", kfgqpc=self.work / synthetic.KFGQPC_FILE
        )

    def test_with_a_tanzil_witness_where_nothing_is_compared(self):
        self.assert_refused(
            r"does not run the comparison \(riwaya synthetic\); it takes no Tanzil text",
            tanzil_text=self.work / synthetic.TEXT_FILE,
        )

    def test_as_an_unapproved_test_copy(self):
        config = self.write_kfgqpc_source(id="unapproved-hafs-kfgqpc", riwaya="hafs", reviews=[])
        self.assert_refused(
            "an unapproved test copy is built from the Tanzil text; the KFGQPC text "
            r"\(registry row 2\) is stored in format 3",
            config,
            unapproved=True,
        )

    def test_a_font_of_another_name(self):
        other = self.work / "other.ttf"
        other.write_bytes(synthetic_kfgqpc_font())
        with self.assertRaises(PackError) as caught:
            build_pack(self.write_kfgqpc_source(), other, self.out, table=self.table)
        self.assertEqual(
            str(caught.exception),
            "the font of a KFGQPC text is KFGQPC's own uthmanic_hafs_v20.ttf (D-198 Q2), not other.ttf",
        )
        self.assert_out_empty()

    def test_a_kfgqpc_file_of_another_name(self):
        config = self.edit_config(
            self.write_kfgqpc_source(), lambda c: c["sources"]["text"].update(file="hafsData.json")
        )
        self.assert_refused("the KFGQPC file is named hafsData.json, not hafsData_v2-0.json as published", config)

    def test_another_kfgqpc_version(self):
        config = self.edit_config(
            self.write_kfgqpc_source(), lambda c: c["sources"]["text"].update(version="1.0")
        )
        self.assert_refused(
            r"the KFGQPC file is read as version 2.0 \(update 13.0\); the description names version 1.0", config
        )

    def test_a_kfgqpc_url_with_a_query(self):
        config = self.edit_config(
            self.write_kfgqpc_source(),
            lambda c: c["sources"]["text"].update(url="https://example.invalid/synthetic/kfgqpc.zip?type=json"),
        )
        self.assert_refused("published with no download options; its URL has a query", config)

    def test_a_file_that_is_not_the_one_recorded(self):
        config = self.edit_config(
            self.write_kfgqpc_source(), lambda c: c["sources"]["text"].update(file_sha256="0" * 64)
        )
        self.assert_refused("sources.text: the file has SHA-256 [0-9a-f]{64}, the description expects 0{64}", config)

    def test_an_ayah_without_its_ending(self):
        config = self.write_kfgqpc_source(with_text(2, 1, lambda text: text[:-1]))
        self.assert_refused(r"ayah 2:1 does not end with U\+00A0 U\+FC00", config)

    def test_a_pause_mark_joined_inside_a_word(self):
        config = self.write_kfgqpc_source(with_text(3, 1, lambda text: text.replace("last", "la" + PAUSE + "st")))
        self.assert_refused(r"ayah 3:1 word 2 holds U\+06D6 before the end of its token", config)

    def test_a_quarter_sign_outside_the_opening(self):
        config = self.write_kfgqpc_source(
            with_text(3, 1, lambda text: text.replace("last", "la" + QUARTER_SIGN + "st"))
        )
        self.assert_refused(r"ayah 3:1 holds U\+06DE, which the profile excludes", config)

    def test_a_no_break_space_inside_the_text(self):
        config = self.write_kfgqpc_source(with_text(3, 1, lambda text: text.replace(" last", NBSP + "last")))
        self.assert_refused(r"ayah 3:1 holds U\+00A0 \(category Zs\) at offset 9", config)

    def test_a_sajda_sign_the_metadata_does_not_list(self):
        config = self.write_kfgqpc_source(with_text(3, 1, lambda text: text.replace("ayah", "ayah" + SAJDA)))
        self.assert_refused(r"ayat 3:1 hold U\+06E9 but are not sajdas of the metadata", config)

    def test_ayah_counts_the_metadata_does_not_give(self):
        config = self.write_kfgqpc_source(metadata_xml=synthetic.synthetic_metadata_xml(suras=suras_with(1, ayas=5)))
        self.assert_refused("surah 1: the metadata gives 5 ayat, the KFGQPC file has 4", config)

    def test_a_code_point_the_font_lacks(self):
        self.font.write_bytes(synthetic_kfgqpc_font(last=0x06FF))
        self.assert_refused(r"the font lacks U\+FC00 \(first in ayah 1:1\)")

    def test_stored_bytes_that_differ_from_the_source(self):
        real = build.database.read_stored_texts

        def flipped(path):
            stored = real(path)
            stored.basmalas[3] = b"X" + stored.basmalas[3][1:]
            return stored

        with mock.patch.object(build.database, "read_stored_texts", flipped):
            self.assert_refused("surah 3 basmala: the stored bytes differ from the source bytes")


class KfgqpcComparisonTest(KfgqpcBuildCase):
    """A hafs build of the KFGQPC text is compared with its Tanzil witness, then stops (D-198 Q3, Q6)."""

    def hafs_source(self, entries):
        return self.write_kfgqpc_source(entries, id="base-hafs-kfgqpc", riwaya="hafs")

    def test_it_needs_the_tanzil_witness(self):
        config = self.hafs_source(kfgqpc_entries())
        with hafs_shaped_profiles():
            self.assert_refused(r"give the Tanzil text XML \(--tanzil-text\)", config)

    def test_a_passing_comparison_still_builds_no_pack(self):
        # The Tanzil text's own bodies, its pause marks standing alone.
        config = self.hafs_source(synthetic.synthetic_kfgqpc_entries())
        with hafs_shaped_profiles():
            message = self.assert_refused(
                "the comparison of the KFGQPC text with its Tanzil witness passes",
                config,
                tanzil_text=self.source / synthetic.TEXT_FILE,
            )
        self.assertIn("its rights row is incomplete (D-198 Q3)", message)

    def test_joined_pause_marks_differ_from_the_witness(self):
        config = self.hafs_source(kfgqpc_entries())
        with hafs_shaped_profiles():
            self.assert_refused(
                "the comparison of the KFGQPC text with its Tanzil witness fails",
                config,
                tanzil_text=self.source / synthetic.TEXT_FILE,
            )
