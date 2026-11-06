"""The KFGQPC comparison (PRD 9.4, P2) on the synthetic source and a synthetic KFGQPC-shaped file."""

import hashlib
import json
import shutil
import tempfile
import unittest
from collections import OrderedDict
from pathlib import Path

import synthetic_source as synthetic
from hqpack import compare
from hqpack.errors import PackError
from hqpack.kfgqpc import read_kfgqpc
from hqpack.known_differences import read_table
from hqpack.profiles import PROFILES
from hqpack.tanzil_metadata import read_tanzil_metadata
from hqpack.tanzil_text import read_tanzil_text

from tests.build_support import surahs_with_ayah

SHIPPED = Path(__file__).resolve().parents[1] / "known_differences.json"
AYAT = 8
NBSP = "\u00a0"
SIGN = "\u06de"
FEWER_QUARTERS = ((1, 1), (1, 3), (2, 1), (3, 1))


def _table(*extra_rules, drop=()):
    document = json.loads(SHIPPED.read_text(encoding="ascii"))
    document["rules"] = [r for r in document["rules"] if r["id"] not in drop] + list(extra_rules)
    return read_table(json.dumps(document).encode("ascii"))


def _equivalence(kfgqpc, tanzil, applies_to, rule_id="E-1"):
    return {
        "id": rule_id,
        "kind": "equivalence",
        "code_points": {"kfgqpc": kfgqpc, "tanzil": tanzil},
        "applies_to": applies_to,
        "reason": "Synthetic rule for a test",
        "approved_by": "owner and proofreader (synthetic)",
        "date": "2026-01-01",
    }


def _id(surah, ayah):
    return sum(len(s[2]) for s in synthetic.SYNTHETIC_SURAHS[: surah - 1]) + ayah - 1


class CompareCase(unittest.TestCase):
    def run_compare(self, entries=None, table=None, surahs=None, quarters=None):
        text = read_tanzil_text(
            synthetic.synthetic_text_xml(**({} if surahs is None else {"surahs": surahs}))
        )
        metadata = read_tanzil_metadata(
            synthetic.synthetic_metadata_xml(**({} if quarters is None else {"quarters": quarters}))
        )
        entries = synthetic.synthetic_kfgqpc_entries() if entries is None else entries
        witness = read_kfgqpc(synthetic.synthetic_kfgqpc_json(entries), AYAT)
        report = compare.compare(text, metadata, witness, _table() if table is None else table)
        data = compare.encode_report(report)
        self.assert_no_text(data.decode("ascii"))
        return report

    def assert_no_text(self, output):
        self.assertTrue(output.isascii())
        self.assertNotIn("Synthetic", output)
        self.assertNotIn("synthetic", output.replace("synthetic)", ""))

    def entries_with_text(self, surah, ayah, change):
        entries = synthetic.synthetic_kfgqpc_entries()
        entry = entries[_id(surah, ayah)]
        entry["aya_text"] = change(entry["aya_text"])
        return entries

    def assert_fails_with(self, report, key, count=1):
        self.assertFalse(report["passed"])
        self.assertEqual(len(report[key]), count, report[key])
        for other in ("presentation_problems", "table_problems", "differences", "page_differences", "juz_differences"):
            if other != key:
                self.assertEqual(report[other], [], other)


class EqualTextsTest(CompareCase):
    def test_equal_texts_pass(self):
        report = self.run_compare()
        self.assertTrue(report["passed"])
        self.assertEqual(report["ayat"], AYAT)
        self.assertEqual([(r["id"], r["applied"]) for r in report["rules"]], [("P-1", AYAT), ("P-2", AYAT)])
        self.assertEqual(report["differences"], [])
        self.assertEqual(report["patterns"], [])

    def test_the_summary_is_counts(self):
        self.assertEqual(
            compare.summary(self.run_compare()),
            "ayat 8, undocumented differences 0 in 0 patterns, presentation problems 0, "
            "table problems 0, page differences 0, juz differences 0",
        )

    def test_the_report_is_deterministic(self):
        entries = self.entries_with_text(1, 2, lambda t: t.replace("\u06d6", "\u06d7"))
        first = compare.encode_report(self.run_compare(entries))
        self.assertEqual(first, compare.encode_report(self.run_compare(entries)))

    def test_a_report_holding_a_character_outside_ascii_is_not_written(self):
        with self.assertRaisesRegex(PackError, "outside ASCII"):
            compare.encode_report(OrderedDict([("x", ["\u0646"])]))


class AyahEndRuleTest(CompareCase):
    def test_a_wrong_number_glyph_stops(self):
        entries = self.entries_with_text(1, 2, lambda t: t[:-1] + "\ufc02")
        report = self.run_compare(entries)
        self.assertFalse(report["passed"])
        (problem,) = report["presentation_problems"]
        self.assertEqual(problem["address"], "hafs:1:2")
        self.assertEqual(problem["rule"], "P-1")
        self.assertEqual(problem["found"], ["U+00A0", "U+FC02"])
        self.assertIn("U+FC02, not U+FC01 for ayah 2 (it is the glyph of ayah 3)", problem["problem"])
        # Not removed, so the comparison shows it too.
        (difference,) = report["differences"]
        self.assertEqual(difference["kfgqpc"]["sequence"], ["U+00A0", "U+FC02"])

    def test_the_glyph_of_the_previous_surah_numbering_stops(self):
        # 2:1 carrying the glyph that 1:4 had: right shape, wrong number.
        entries = self.entries_with_text(2, 1, lambda t: t[:-1] + "\ufc03")
        report = self.run_compare(entries)
        self.assertEqual([p["address"] for p in report["presentation_problems"]], ["hafs:2:1"])

    def test_an_ayah_without_the_separator_stops(self):
        entries = self.entries_with_text(3, 1, lambda t: t[:-2] + "x" + t[-1])
        report = self.run_compare(entries)
        (problem,) = report["presentation_problems"]
        self.assertEqual(problem["address"], "hafs:3:1")
        self.assertIn("does not end with U+00A0 and the number glyph U+FC00", problem["problem"])
        self.assertFalse(report["passed"])

    def test_without_the_rule_every_ayah_differs(self):
        report = self.run_compare(table=_table(drop=("P-1",)))
        self.assertFalse(report["passed"])
        self.assertEqual(len(report["differences"]), AYAT)
        self.assertEqual(report["patterns"][0]["kfgqpc"], ["U+00A0", "U+FC00"])
        self.assertEqual(report["patterns"][0]["count"], 3)


class QuarterRuleTest(CompareCase):
    def test_the_sign_at_an_ayah_that_is_not_a_quarter_start_stops(self):
        report = self.run_compare(quarters=FEWER_QUARTERS)
        self.assert_fails_with(report, "presentation_problems", 4)
        self.assertEqual(
            [p["address"] for p in report["presentation_problems"]],
            ["hafs:1:2", "hafs:1:4", "hafs:2:2", "hafs:2:3"],
        )
        self.assertIn("is not a quarter start", report["presentation_problems"][0]["problem"])

    def test_a_quarter_start_without_the_sign_stops(self):
        entries = self.entries_with_text(2, 2, lambda t: t[2:])
        report = self.run_compare(entries)
        self.assert_fails_with(report, "presentation_problems")
        self.assertEqual(report["presentation_problems"][0]["address"], "hafs:2:2")
        self.assertIn("does not open with the quarter sign", report["presentation_problems"][0]["problem"])

    def test_the_sign_without_its_separator_is_not_removed(self):
        entries = self.entries_with_text(1, 3, lambda t: SIGN + t[2:])
        report = self.run_compare(entries)
        self.assertFalse(report["passed"])
        self.assertEqual(report["presentation_problems"][0]["address"], "hafs:1:3")
        self.assertEqual(report["differences"][0]["kfgqpc"]["sequence"], ["U+06DE"])

    def test_without_the_rule_every_quarter_start_differs(self):
        report = self.run_compare(table=_table(drop=("P-2",)))
        self.assert_fails_with(report, "differences", AYAT)
        self.assertEqual(report["patterns"][0]["kfgqpc"], ["U+06DE", "U+00A0"])


class DifferenceTest(CompareCase):
    def test_an_unlisted_difference_in_a_mark_stops_with_its_place(self):
        entries = self.entries_with_text(1, 2, lambda t: t.replace("\u06d6", "\u06d7"))
        report = self.run_compare(entries)
        self.assert_fails_with(report, "differences")
        (difference,) = report["differences"]
        self.assertEqual(difference["address"], "hafs:1:2")
        self.assertEqual((difference["word"], difference["in_mark"]), (1, True))
        self.assertEqual(
            difference["kfgqpc"],
            {"before": ["U+0063", "U+0020"], "sequence": ["U+06D7"], "after": ["U+0020", "U+0074"]},
        )
        self.assertEqual(difference["tanzil"]["sequence"], ["U+06D6"])
        self.assertEqual(
            report["patterns"],
            [{"kfgqpc": ["U+06D7"], "tanzil": ["U+06D6"], "count": 1, "first": ["hafs:1:2"]}],
        )

    def test_an_unlisted_difference_in_a_word(self):
        entries = self.entries_with_text(1, 4, lambda t: t.replace("\u062a\u062c", "\u062a\u06e1\u062c"))
        (difference,) = self.run_compare(entries)["differences"]
        self.assertEqual((difference["address"], difference["word"], difference["in_mark"]), ("hafs:1:4", 2, False))
        self.assertEqual(difference["kfgqpc"]["sequence"], ["U+06E1"])
        self.assertEqual(difference["tanzil"]["sequence"], [])
        self.assertEqual(difference["tanzil"]["before"], ["U+0020", "U+062A"])

    def test_canonically_equivalent_orders_are_a_difference(self):
        # No normalisation: shadda then fatha against fatha then shadda.
        surahs = surahs_with_ayah(1, 4, " \u0646\u064e\u0651\u0635 \u062a\u062c\u0631\u064a\u0628\u064a  ")
        entries = synthetic.synthetic_kfgqpc_entries(surahs=surahs)
        entries[_id(1, 4)]["aya_text"] = entries[_id(1, 4)]["aya_text"].replace("\u064e\u0651", "\u0651\u064e")
        report = self.run_compare(entries, surahs=surahs)
        self.assertFalse(report["passed"])
        self.assertEqual({d["address"] for d in report["differences"]}, {"hafs:1:4"})
        self.assertEqual(report["differences"][0]["word"], 1)

    def test_patterns_are_counted_and_sorted(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        for surah, ayah in ((1, 1), (2, 1), (3, 1), (2, 1)):
            entry = entries[_id(surah, ayah)]
            entry["aya_text"] = entry["aya_text"].replace("Synthetic", "Synthet\u06e1c", 1)
        entries[_id(1, 2)]["aya_text"] = entries[_id(1, 2)]["aya_text"].replace("\u06e9", "\u06d6")
        report = self.run_compare(entries)
        self.assertEqual(
            [(p["kfgqpc"], p["tanzil"], p["count"], p["first"]) for p in report["patterns"]],
            [
                (["U+06E1"], ["U+0069"], 3, ["hafs:1:1", "hafs:2:1", "hafs:3:1"]),
                (["U+06D6"], ["U+06E9"], 1, ["hafs:1:2"]),
            ],
        )


class EquivalenceRuleTest(CompareCase):
    def entries(self):
        return self.entries_with_text(1, 4, lambda t: t.replace("\u064e", "\u06e1"))

    def test_a_listed_rule_makes_it_pass(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], ["hafs:1:4"]))
        report = self.run_compare(self.entries(), table)
        self.assertTrue(report["passed"], report)
        self.assertEqual(report["rules"][2], {
            "id": "E-1", "kind": "equivalence", "applies_to": ["hafs:1:4"],
            "approved_by": "owner and proofreader (synthetic)", "applied": 1,
        })

    def test_a_rule_for_every_ayah(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], "every_ayah"))
        self.assertTrue(self.run_compare(self.entries(), table)["passed"])

    def test_a_rule_listed_for_another_ayah_does_not_apply(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], ["hafs:1:3"]))
        report = self.run_compare(self.entries(), table)
        self.assertFalse(report["passed"])
        self.assertEqual(report["differences"][0]["address"], "hafs:1:4")
        self.assertEqual(
            report["table_problems"],
            [{"rule": "E-1", "address": "hafs:1:3", "problem": "not applied in this listed ayah"}],
        )

    def test_a_rule_that_applies_nowhere_stops(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], "every_ayah"))
        report = self.run_compare(table=table)
        self.assert_fails_with(report, "table_problems")
        self.assertEqual(report["table_problems"][0]["problem"], "applied in no ayah")

    def test_the_first_listed_rule_wins_and_rules_do_not_chain(self):
        entries = self.entries_with_text(1, 4, lambda t: t.replace("\u064e", "\u06e1\u06e1"))
        table = _table(
            _equivalence(["U+06E1", "U+06E1"], ["U+064E"], "every_ayah", "E-1"),
            _equivalence(["U+06E1"], ["U+06E1", "U+06E1"], "every_ayah", "E-2"),
        )
        report = self.run_compare(entries, table)
        self.assertEqual(report["table_problems"], [{"rule": "E-2", "problem": "applied in no ayah"}])
        self.assertEqual(report["differences"], [])

    def test_a_listed_address_outside_the_text(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], ["hafs:3:2"]))
        with self.assertRaisesRegex(PackError, "rule E-1 applies to hafs:3:2, not an ayah of the text"):
            self.run_compare(self.entries(), table)


class PageAndJuzTest(CompareCase):
    def test_a_page_difference_stops(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[_id(2, 1)]["page"] = 3
        report = self.run_compare(entries)
        self.assert_fails_with(report, "page_differences")
        self.assertEqual(report["page_differences"], [{"address": "hafs:2:1", "kfgqpc": 3, "tanzil_metadata": 2}])

    def test_a_juz_difference_stops(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[_id(1, 4)]["jozz"] = 2
        report = self.run_compare(entries)
        self.assert_fails_with(report, "juz_differences")
        self.assertEqual(report["juz_differences"], [{"address": "hafs:1:4", "kfgqpc": 2, "tanzil_metadata": 1}])


class StructureTest(CompareCase):
    def test_the_two_files_list_other_ayat(self):
        surahs = [list(s) for s in synthetic.SYNTHETIC_SURAHS]
        surahs[0][2], surahs[1][2] = surahs[0][2][:3], surahs[0][2][3:] + surahs[1][2]
        entries = synthetic.synthetic_kfgqpc_entries(surahs=[tuple(s) for s in surahs])
        with self.assertRaisesRegex(PackError, "KFGQPC id 4 is 2:1 where the Tanzil text has 1:4"):
            self.run_compare(entries)


class WordNumberTest(unittest.TestCase):
    def test_words_marks_and_spaces(self):
        numbers = compare._word_numbers(" ab \u06d6 cd")
        self.assertEqual(
            numbers,
            [(0, False), (1, False), (1, False), (1, False), (1, True), (1, True),
             (2, False), (2, False), (2, False)],
        )


class RunComparisonTest(unittest.TestCase):
    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack compare "))
        self.addCleanup(shutil.rmtree, str(self.work), True)

    def test_the_inputs_are_recorded(self):
        path = self.work / synthetic.KFGQPC_FILE
        path.write_bytes(synthetic.synthetic_kfgqpc_json())
        text = read_tanzil_text(synthetic.synthetic_text_xml())
        metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml())
        report = compare.run_comparison(text, metadata, path, SHIPPED, PROFILES["synthetic"])
        self.assertEqual(report["format"], "holyquran-kfgqpc-comparison")
        self.assertEqual(
            report["kfgqpc"],
            {
                "registry_row": 2,
                "file": "hafsData_v2-0.json",
                "version": "2.0 (update 13.0)",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            },
        )
        self.assertEqual(report["table"]["version"], 1)
        self.assertRegex(report["table"]["sha256"], "^[0-9a-f]{64}$")
        self.assertTrue(report["passed"])


if __name__ == "__main__":
    unittest.main()
