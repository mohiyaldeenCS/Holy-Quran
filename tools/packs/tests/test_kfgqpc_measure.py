"""The KFGQPC measurement (D-195), on synthetic KFGQPC-shaped and Tanzil-shaped files only."""

import io
import json

import synthetic_source as synthetic
from hqpack import cli
from hqpack.font import read_font
from hqpack.kfgqpc import read_kfgqpc
from hqpack.known_differences import read_table
from hqpack.kfgqpc_measure import TOKEN_MAP_NOT_MEASURED, encode_report, measure
from hqpack.profiles import PROFILES
from hqpack.tanzil_metadata import read_tanzil_metadata
from hqpack.tanzil_text import read_tanzil_text

from tests.build_support import FONT, REPO, BuildCase, hafs_shaped_profiles, surahs_with_ayah, synthetic_table_document

AYAT = PROFILES["synthetic"].ayat
TABLE = read_table(json.dumps(synthetic_table_document()).encode("ascii"))


def _ayat(entries=None):
    return read_kfgqpc(synthetic.synthetic_kfgqpc_json(entries), AYAT)


def _entries(surahs):
    return synthetic.synthetic_kfgqpc_entries(surahs=surahs)


def _every_code_point(ayat):
    return frozenset(ord(c) for aya in ayat for c in aya.text + aya.emlaey)


def _measure(ayat, font=None, text=None, metadata=None):
    return measure(ayat, _every_code_point(ayat) if font is None else font, TABLE, text, metadata)


class MeasureTest(BuildCase):
    def test_a_pause_mark_joined_to_letters_is_counted_per_mark(self):
        ayat = _ayat(_entries(surahs_with_ayah(1, 1, "Syntheticۖ oneۗ")))
        pause = _measure(ayat)["pause_marks_joined_to_letters"]
        self.assertEqual(pause["tokens"], 2)
        self.assertEqual(pause["ayat"], 1)
        self.assertEqual(pause["per_mark"], {"U+06D6": 1, "U+06D7": 1})
        self.assertEqual(pause["standalone_mark_tokens"], 3)
        self.assertEqual(pause["first"], ["hafs:1:1"])

    def test_no_break_spaces_by_position(self):
        spaces = _measure(_ayat(_entries(surahs_with_ayah(3, 1, "Synthetic last"))))["no_break_spaces"]
        self.assertEqual(spaces["at_ayah_end"], AYAT)
        self.assertEqual(spaces["at_quarter_opening"], 5)
        self.assertEqual(spaces["elsewhere"], {"count": 1, "ayat": 1, "first": ["hafs:3:1"]})
        self.assertEqual(spaces["total"], AYAT + 5 + 1)

    def test_an_ayah_without_its_ayah_end_tail_is_counted(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[0]["aya_text"] = entries[0]["aya_text"][:-1]
        report = _measure(_ayat(entries))
        self.assertEqual(report["ayah_end_tail"], {"missing": 1, "first": ["hafs:1:1"]})
        self.assertEqual(report["no_break_spaces"]["elsewhere"]["first"], ["hafs:1:1"])

    def test_code_points_the_font_lacks(self):
        ayat = _ayat()
        missing = _measure(ayat, font=_every_code_point(ayat) - {0x06E9})["missing_from_font"]
        self.assertEqual(missing["aya_text"], [{"code_point": "U+06E9", "occurrences": 2, "ayat": 2}])
        self.assertEqual(missing["aya_text_emlaey"], [{"code_point": "U+06E9", "occurrences": 2, "ayat": 2}])

    def test_emlaey_token_counts_against_the_uthmani_tokens(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[7]["aya_text_emlaey"] = "Synthetic last ayah extra"
        tokens = _measure(_ayat(entries))["emlaey_against_uthmani_tokens"]
        # 1:4 opens a quarter with the sign and U+00A0 before a leading space: one more Uthmani token.
        self.assertEqual(tokens["histogram_emlaey_minus_uthmani"], {"-1": 1, "0": AYAT - 2, "+1": 1})
        self.assertEqual(tokens["ayat_differing"], 2)
        self.assertEqual(tokens["first"], ["hafs:1:4", "hafs:3:1"])

    def test_empty_runs_are_counted_and_not_tokens(self):
        tokens = _measure(_ayat())["tokens"]["emlaey"]
        self.assertEqual(tokens["ayat_with_empty_runs"], 2)
        self.assertEqual(tokens["first"], ["hafs:1:4", "hafs:2:1"])

    def test_the_sajda_sign_against_the_tanzil_list(self):
        metadata = read_tanzil_metadata(
            synthetic.synthetic_metadata_xml(sajdas=((1, 2, "recommended"), (3, 1, "obligatory")))
        )
        sajda = _measure(_ayat(), metadata=metadata)["sajda_sign"]
        self.assertEqual(sajda["kfgqpc_ayat"], 2)
        self.assertEqual(sajda["tanzil"], 2)
        self.assertEqual(sajda["both"], 1)
        self.assertEqual(sajda["kfgqpc_only"], ["hafs:2:3"])
        self.assertEqual(sajda["tanzil_only"], ["hafs:3:1"])

    def test_without_tanzil_the_tanzil_parts_are_not_measured(self):
        report = _measure(_ayat())
        self.assertTrue(report["sajda_sign"]["tanzil"].startswith("not measured"))
        self.assertEqual(report["tanzil_token_map"], TOKEN_MAP_NOT_MEASURED)

    def test_tanzil_token_counts_against_kfgqpc(self):
        text = read_tanzil_text(synthetic.synthetic_text_xml(surahs_with_ayah(2, 1, "Synthetic")))
        metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml())
        token_map = _measure(_ayat(), text=text, metadata=metadata)["tanzil_token_map"]
        self.assertEqual(token_map["map"], TOKEN_MAP_NOT_MEASURED)
        self.assertEqual(token_map["histogram_tanzil_minus_kfgqpc_tokens"], {"-2": 1, "-1": 1, "0": AYAT - 2})
        self.assertEqual(token_map["first"], ["hafs:1:4", "hafs:2:1"])

    def test_the_report_is_ascii_and_deterministic(self):
        first = encode_report(_measure(_ayat()))
        self.assertTrue(first.isascii())
        self.assertEqual(first, encode_report(_measure(_ayat())))


class MeasureCommandTest(BuildCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with hafs_shaped_profiles():
            code = cli.main([str(a) for a in argv], out=out, err=err)
        return code, out.getvalue(), err.getvalue()

    def arguments(self, report):
        self.write_source()
        return (
            "kfgqpc-measure", "--kfgqpc", self.write_kfgqpc(), "--font", FONT, "--table", self.write_table(),
            "--text", self.source / synthetic.TEXT_FILE, "--metadata", self.source / synthetic.METADATA_FILE,
            "--report", report,
        )

    def test_writes_the_report_and_prints_counts(self):
        report = self.work / "report.json"
        code, out, err = self.run_cli(*self.arguments(report))
        self.assertEqual((code, err), (0, ""))
        data = report.read_bytes()
        self.assertTrue(data.isascii())
        document = json.loads(data)
        self.assertEqual(document["ayat"], AYAT)
        self.assertEqual(document["inputs"]["font"]["sha256"], read_font(FONT.read_bytes()).sha256)
        self.assertEqual(document["sajda_sign"]["both"], 2)
        self.assertTrue(out.isascii())

    def test_a_report_inside_a_git_tree_is_refused(self):
        code, _, err = self.run_cli(*self.arguments(REPO / "report.json"))
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("Git working tree", err)
        self.assertFalse((REPO / "report.json").exists())

    def test_text_without_metadata_is_a_usage_error(self):
        arguments = list(self.arguments(self.work / "report.json"))
        index = arguments.index("--metadata")
        del arguments[index : index + 2]
        code, _, _ = self.run_cli(*arguments)
        self.assertEqual(code, cli.EX_USAGE)
