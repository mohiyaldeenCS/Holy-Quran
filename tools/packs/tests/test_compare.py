"""The KFGQPC comparison (PRD 9.4, P2) on the synthetic source and a synthetic KFGQPC-shaped file.

The synthetic KFGQPC file has the published presentation: every ayah ends with
U+00A0 and its number glyph, and U+06DE U+00A0 opens every quarter start but
the three that open a surah (1:1, 2:1, 3:1), which carry no sign (P-3).
"""

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

from tests.build_support import TABLE as SHIPPED, surahs_with_ayah, synthetic_table_document

AYAT = 8
NBSP = "\u00a0"
SIGN = "\u06de"
FEWER_QUARTERS = ((1, 1), (1, 3), (2, 1), (3, 1))
EVERY_LIST = ("presentation_problems", "table_problems", "differences", "page_differences", "juz_differences", "quarter_differences")


def _table(*extra_rules, drop=()):
    """The shipped table without P-4 (it names hafs:2:286), less `drop`, plus `extra_rules`."""
    document = synthetic_table_document()
    document["rules"] = [r for r in document["rules"] if r["id"] not in drop] + list(extra_rules)
    return read_table(json.dumps(document).encode("ascii"))


def _shipped_rule(rule_id, **fields):
    (rule,) = [r for r in json.loads(SHIPPED.read_text(encoding="ascii"))["rules"] if r["id"] == rule_id]
    return dict(rule, **fields)


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
    def run_compare(self, entries=None, table=None, surahs=None, quarters=None, ayat=AYAT, **metadata_lists):
        text = read_tanzil_text(
            synthetic.synthetic_text_xml(**({} if surahs is None else {"surahs": surahs}))
        )
        if quarters is not None:
            metadata_lists["quarters"] = quarters
        metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml(**metadata_lists))
        entries = synthetic.synthetic_kfgqpc_entries() if entries is None else entries
        witness = read_kfgqpc(synthetic.synthetic_kfgqpc_json(entries), ayat)
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
        for other in EVERY_LIST:
            if other != key:
                self.assertEqual(report[other], [], other)


class EqualTextsTest(CompareCase):
    def test_equal_texts_pass(self):
        report = self.run_compare()
        self.assertTrue(report["passed"])
        self.assertEqual(report["ayat"], AYAT)
        self.assertEqual(
            [(r["id"], r["applied"]) for r in report["rules"]], [("P-1", AYAT), ("P-2", 5), ("P-3", 3)]
        )
        for key in EVERY_LIST:
            self.assertEqual(report[key], [], key)
        self.assertEqual(report["differences"], [])
        self.assertEqual(report["patterns"], [])

    def test_the_summary_is_counts(self):
        self.assertEqual(
            compare.summary(self.run_compare()),
            "ayat 8, undocumented differences 0 in 0 patterns, presentation problems 0, "
            "table problems 0, page differences 0, juz differences 0, quarter differences 0",
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


class AyahEndSeparatorRuleTest(CompareCase):
    """P-4: an ayah-end separator named for listed addresses only."""

    def table(self, address="hafs:2:3"):
        return _table(_shipped_rule("P-4", applies_to=[address]))

    def entries(self, separator=" ", glyph="\ufc02"):
        return self.entries_with_text(2, 3, lambda t: t[:-2] + separator + glyph)

    def test_the_listed_ayah_passes_with_its_separator(self):
        report = self.run_compare(self.entries(), self.table())
        self.assertTrue(report["passed"], report)
        applied = {r["id"]: r["applied"] for r in report["rules"]}
        self.assertEqual((applied["P-1"], applied["P-4"]), (AYAT - 1, 1))
        self.assertEqual(report["rules"][1]["applies_to"], ["hafs:2:3"])

    def test_without_the_rule_it_stops(self):
        report = self.run_compare(self.entries())
        self.assertFalse(report["passed"])
        (problem,) = report["presentation_problems"]
        self.assertEqual((problem["address"], problem["rule"]), ("hafs:2:3", "P-1"))
        self.assertEqual(problem["found"], ["U+0020", "U+FC02"])

    def test_the_listed_ayah_with_the_usual_separator_stops(self):
        report = self.run_compare(table=self.table())
        (problem,) = report["presentation_problems"]
        self.assertEqual((problem["address"], problem["rule"]), ("hafs:2:3", "P-4"))
        self.assertIn("does not end with U+0020 and the number glyph U+FC02", problem["problem"])
        self.assertFalse(report["passed"])

    def test_the_glyph_is_still_checked(self):
        report = self.run_compare(self.entries(glyph="\ufc03"), self.table())
        (problem,) = report["presentation_problems"]
        self.assertEqual((problem["address"], problem["rule"]), ("hafs:2:3", "P-4"))
        self.assertIn("U+FC03, not U+FC02 for ayah 3", problem["problem"])

    def test_it_applies_at_its_address_only(self):
        entries = self.entries_with_text(2, 2, lambda t: t[:-2] + " " + t[-1])
        report = self.run_compare(entries, self.table())
        problems = [(p["address"], p["rule"]) for p in report["presentation_problems"]]
        self.assertEqual(problems, [("hafs:2:2", "P-1"), ("hafs:2:3", "P-4")])

    def test_the_shipped_address_is_not_in_the_synthetic_text(self):
        with self.assertRaisesRegex(PackError, "rule P-4 applies to hafs:2:286, not an ayah of the text"):
            self.run_compare(table=_table(_shipped_rule("P-4")))


class QuarterRuleTest(CompareCase):
    def test_the_sign_at_an_ayah_that_is_not_a_quarter_start_is_a_quarter_difference(self):
        # The kind of hafs:15:49: a division difference (P2), not a presentation problem.
        report = self.run_compare(quarters=FEWER_QUARTERS)
        self.assert_fails_with(report, "quarter_differences", 4)
        self.assertEqual(
            [d["address"] for d in report["quarter_differences"]],
            ["hafs:1:2", "hafs:1:4", "hafs:2:2", "hafs:2:3"],
        )
        self.assertEqual(
            report["quarter_differences"][0],
            {
                "address": "hafs:1:2",
                "kfgqpc_quarter_start": True,
                "tanzil_quarter_start": False,
                "kfgqpc_quarters": [
                    {"quarter": 1, "start": "hafs:1:1"},
                    {"quarter": 2, "start": "hafs:1:2"},
                    {"quarter": 3, "start": "hafs:1:3"},
                    {"quarter": 4, "start": "hafs:1:4"},
                ],
                "tanzil_quarters": [
                    {"quarter": 1, "start": "hafs:1:1"},
                    {"quarter": 2, "start": "hafs:1:3"},
                    {"quarter": 3, "start": "hafs:2:1"},
                ],
            },
        )
        self.assertEqual(
            [q["start"] for q in report["quarter_differences"][3]["tanzil_quarters"]],
            ["hafs:1:3", "hafs:2:1", "hafs:3:1"],
        )
        self.assertEqual(
            [q["quarter"] for q in report["quarter_differences"][3]["kfgqpc_quarters"]], [5, 6, 7, 8]
        )

    def test_a_quarter_start_without_the_sign_is_a_quarter_difference(self):
        entries = self.entries_with_text(2, 2, lambda t: t[2:])
        report = self.run_compare(entries)
        self.assert_fails_with(report, "quarter_differences")
        (difference,) = report["quarter_differences"]
        self.assertEqual(
            (difference["address"], difference["kfgqpc_quarter_start"], difference["tanzil_quarter_start"]),
            ("hafs:2:2", False, True),
        )

    def test_the_sign_without_its_separator_is_not_removed(self):
        entries = self.entries_with_text(1, 3, lambda t: SIGN + t[2:])
        report = self.run_compare(entries)
        self.assertFalse(report["passed"])
        (problem,) = report["presentation_problems"]
        self.assertEqual((problem["address"], problem["rule"]), ("hafs:1:3", "P-2"))
        self.assertIn("opens with the quarter sign U+06DE not followed by U+00A0", problem["problem"])
        self.assertEqual(report["differences"][0]["kfgqpc"]["sequence"], ["U+06DE"])
        # Still a KFGQPC quarter start: the ayah opens with the sign.
        self.assertEqual(report["quarter_differences"], [])

    def test_the_sign_and_separator_inside_an_ayah_are_not_removed(self):
        entries = self.entries_with_text(1, 2, lambda t: t[:4] + SIGN + NBSP + t[4:])
        report = self.run_compare(entries)
        self.assert_fails_with(report, "differences")
        (difference,) = report["differences"]
        self.assertEqual(difference["address"], "hafs:1:2")
        self.assertEqual(difference["kfgqpc"]["sequence"], ["U+06DE", "U+00A0"])
        self.assertEqual({r["id"]: r["applied"] for r in report["rules"]}["P-2"], 5)

    def test_without_the_rule_every_sign_differs_and_quarters_are_not_compared(self):
        report = self.run_compare(table=_table(drop=("P-2", "P-3")))
        self.assertFalse(report["passed"])
        self.assertEqual(len(report["differences"]), 5)
        self.assertEqual(report["patterns"][0]["kfgqpc"], ["U+06DE", "U+00A0"])
        self.assertEqual(
            report["table_problems"],
            [{"rule": None, "problem": "no presentation rule at quarter_start, so KFGQPC's quarters are not known"}],
        )
        self.assertEqual(report["quarter_differences"], [])


class SurahOpeningQuarterRuleTest(CompareCase):
    """P-3: a quarter start at the first ayah of a surah carries no sign in KFGQPC."""

    def test_without_the_rule_the_surah_openings_are_quarter_differences(self):
        report = self.run_compare(table=_table(drop=("P-3",)))
        self.assert_fails_with(report, "quarter_differences", 3)
        self.assertEqual(
            [(d["address"], d["kfgqpc_quarter_start"], d["tanzil_quarter_start"]) for d in report["quarter_differences"]],
            [("hafs:1:1", False, True), ("hafs:2:1", False, True), ("hafs:3:1", False, True)],
        )

    def test_a_surah_opening_quarter_start_with_the_sign_stops(self):
        entries = self.entries_with_text(2, 1, lambda t: SIGN + NBSP + t)
        report = self.run_compare(entries)
        self.assert_fails_with(report, "presentation_problems")
        (problem,) = report["presentation_problems"]
        self.assertEqual((problem["address"], problem["rule"]), ("hafs:2:1", "P-3"))
        self.assertIn("opens a surah with the quarter sign", problem["problem"])

    def test_a_surah_opening_that_is_no_quarter_start_and_has_no_sign_passes(self):
        quarters = tuple(q for q in synthetic.SYNTHETIC_QUARTERS if q != (2, 1))
        entries = synthetic.synthetic_kfgqpc_entries(quarters=quarters)
        report = self.run_compare(entries, quarters=quarters)
        self.assertTrue(report["passed"], report)
        self.assertEqual({r["id"]: r["applied"] for r in report["rules"]}["P-3"], 2)

    def test_a_surah_opening_with_the_sign_that_is_no_quarter_start_stops_twice(self):
        quarters = tuple(q for q in synthetic.SYNTHETIC_QUARTERS if q != (2, 1))
        entries = synthetic.synthetic_kfgqpc_entries(quarters=quarters)
        entries[_id(2, 1)]["aya_text"] = SIGN + NBSP + entries[_id(2, 1)]["aya_text"]
        report = self.run_compare(entries, quarters=quarters)
        self.assertEqual([p["rule"] for p in report["presentation_problems"]], ["P-3"])
        self.assertEqual(
            [(d["address"], d["kfgqpc_quarter_start"]) for d in report["quarter_differences"]], [("hafs:2:1", True)]
        )

    def test_it_does_not_accept_a_missing_sign_inside_a_surah(self):
        entries = self.entries_with_text(1, 2, lambda t: t[2:])
        report = self.run_compare(entries)
        self.assertEqual([d["address"] for d in report["quarter_differences"]], ["hafs:1:2"])
        self.assertEqual({r["id"]: r["applied"] for r in report["rules"]}["P-3"], 3)


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
            {"before": ["U+0063", "U+0020"], "sequence": ["U+06D7"], "length": 1, "after": ["U+0020", "U+0074"]},
        )
        self.assertEqual(difference["tanzil"]["sequence"], ["U+06D6"])
        self.assertEqual(
            report["patterns"],
            [
                {
                    "kfgqpc": ["U+06D7"], "kfgqpc_length": 1, "tanzil": ["U+06D6"], "tanzil_length": 1,
                    "count": 1, "first": ["hafs:1:2"],
                }
            ],
        )

    def test_a_long_sequence_is_capped_at_eight_code_points_with_its_length(self):
        entries = self.entries_with_text(1, 4, lambda t: t.replace("\u062a\u062c", "\u062a" + "\u06e1" * 11 + "\u062c"))
        report = self.run_compare(entries)
        (difference,) = report["differences"]
        self.assertEqual(difference["kfgqpc"]["sequence"], ["U+06E1"] * compare.SEQUENCE_CAP)
        self.assertEqual(difference["kfgqpc"]["length"], 11)
        self.assertEqual((difference["tanzil"]["sequence"], difference["tanzil"]["length"]), ([], 0))
        self.assertEqual(len(difference["kfgqpc"]["after"]), compare.CONTEXT)
        (pattern,) = report["patterns"]
        self.assertEqual((pattern["kfgqpc"], pattern["kfgqpc_length"]), (["U+06E1"] * 8, 11))
        self.assertEqual((pattern["tanzil"], pattern["tanzil_length"]), ([], 0))

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


class WhitespaceTest(CompareCase):
    """Leading or trailing white space in aya_text is a difference, never trimmed; str.strip() would also remove U+00A0."""

    def test_trailing_white_space_after_the_number_glyph(self):
        for space in (" ", NBSP):
            with self.subTest(space=hex(ord(space))):
                report = self.run_compare(self.entries_with_text(1, 2, lambda t: t + space))
                self.assertFalse(report["passed"])
                (problem,) = report["presentation_problems"]
                self.assertEqual(problem["address"], "hafs:1:2")
                self.assertEqual(problem["found"], ["U+FC01", "U+%04X" % ord(space)])
                self.assertEqual([d["address"] for d in report["differences"]], ["hafs:1:2"])

    def test_leading_white_space_at_an_ayah_without_a_sign(self):
        for space in (" ", NBSP):
            with self.subTest(space=hex(ord(space))):
                report = self.run_compare(self.entries_with_text(2, 1, lambda t: space + t))
                self.assert_fails_with(report, "differences")
                (difference,) = report["differences"]
                self.assertEqual(difference["address"], "hafs:2:1")
                self.assertEqual(difference["kfgqpc"]["sequence"], ["U+%04X" % ord(space)])

    def test_leading_white_space_before_the_quarter_sign(self):
        for space in (" ", NBSP):
            with self.subTest(space=hex(ord(space))):
                report = self.run_compare(self.entries_with_text(1, 3, lambda t: space + t))
                self.assertFalse(report["passed"])
                self.assertEqual([d["address"] for d in report["differences"]], ["hafs:1:3"])
                self.assertEqual(report["differences"][0]["kfgqpc"]["sequence"][0], "U+%04X" % ord(space))
                self.assertEqual([d["address"] for d in report["quarter_differences"]], ["hafs:1:3"])


class AyahEndInsideTest(CompareCase):
    def test_the_separator_and_number_glyph_inside_an_ayah_are_not_removed(self):
        entries = self.entries_with_text(1, 4, lambda t: t[:4] + NBSP + "\ufc03" + t[4:])
        report = self.run_compare(entries)
        self.assert_fails_with(report, "differences")
        (difference,) = report["differences"]
        self.assertEqual(difference["address"], "hafs:1:4")
        self.assertEqual(difference["kfgqpc"]["sequence"], ["U+00A0", "U+FC03"])
        self.assertEqual({r["id"]: r["applied"] for r in report["rules"]}["P-1"], AYAT)


class EquivalenceRuleTest(CompareCase):
    def entries(self):
        return self.entries_with_text(1, 4, lambda t: t.replace("\u064e", "\u06e1"))

    def test_a_listed_rule_makes_it_pass(self):
        table = _table(_equivalence(["U+06E1"], ["U+064E"], ["hafs:1:4"]))
        report = self.run_compare(self.entries(), table)
        self.assertTrue(report["passed"], report)
        self.assertEqual(report["rules"][3], {
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

    def test_a_metadata_list_that_does_not_start_at_1_1_stops(self):
        for kind, points in (
            ("juz", {"juzs": ((1, 2), (2, 1))}),
            ("quarter", {"quarters": ((1, 2), (1, 3), (2, 1), (3, 1))}),
            ("page", {"pages": ((1, 4), (2, 2), (3, 1))}),
        ):
            with self.subTest(kind=kind):
                with self.assertRaisesRegex(PackError, "the metadata's %s list does not start at 1:1" % kind):
                    self.run_compare(**points)


class StructureTest(CompareCase):
    def test_the_two_files_list_other_ayat(self):
        surahs = [list(s) for s in synthetic.SYNTHETIC_SURAHS]
        surahs[0][2], surahs[1][2] = surahs[0][2][:3], surahs[0][2][3:] + surahs[1][2]
        entries = synthetic.synthetic_kfgqpc_entries(surahs=[tuple(s) for s in surahs])
        with self.assertRaisesRegex(PackError, "KFGQPC id 4 is 2:1 where the Tanzil text has 1:4"):
            self.run_compare(entries)

    def test_the_kfgqpc_file_has_fewer_ayat(self):
        entries = synthetic.synthetic_kfgqpc_entries()[:-1]
        with self.assertRaisesRegex(PackError, "the Tanzil text has 8 ayat, the KFGQPC file 7"):
            self.run_compare(entries, ayat=AYAT - 1)

    def test_the_kfgqpc_file_has_more_ayat(self):
        surahs = surahs_with_ayah(3, 1, "Synthetic last ayah")
        surahs[2] = surahs[2][:2] + (surahs[2][2] + ("Synthetic extra ayah",),)
        entries = synthetic.synthetic_kfgqpc_entries(surahs=surahs)
        with self.assertRaisesRegex(PackError, "the Tanzil text has 8 ayat, the KFGQPC file 9"):
            self.run_compare(entries, ayat=AYAT + 1)


class TraceTest(CompareCase):
    """The places the review page shows: the report's differences with ranges in both published texts."""

    def traced(self, entries, table=None, surahs=None):
        text = read_tanzil_text(
            synthetic.synthetic_text_xml(**({} if surahs is None else {"surahs": surahs}))
        )
        metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml())
        witness = read_kfgqpc(synthetic.synthetic_kfgqpc_json(entries), AYAT)
        trace = compare.Trace()
        report = compare.compare(text, metadata, witness, _table() if table is None else table, trace)
        untraced = compare.compare(text, metadata, witness, _table() if table is None else table)
        self.assertEqual(compare.encode_report(report), compare.encode_report(untraced))
        return report, trace

    def test_every_place_points_at_its_sequences(self):
        entries = self.entries_with_text(1, 2, lambda t: t.replace("\u06d6", "\u06d7").replace("two", "tw"))
        entries[_id(2, 2)]["aya_text"] = entries[_id(2, 2)]["aya_text"].replace(" \u06d7", "\u06d7")
        report, trace = self.traced(entries)
        self.assertEqual(len(trace.places), len(report["differences"]))
        self.assertEqual(len(trace.places), 3)
        for place, difference in zip(trace.places, report["differences"]):
            self.assertEqual("hafs:%d:%d" % place.address, difference["address"])
            self.assertEqual((place.word, place.in_mark), (difference["word"], difference["in_mark"]))
            self.assertEqual(place.kfgqpc_text[slice(*place.kfgqpc)], place.kfgqpc_sequence)
            self.assertEqual(place.tanzil_text[slice(*place.tanzil)], place.tanzil_sequence)
            self.assertEqual([compare.code_point(c) for c in place.kfgqpc_sequence], difference["kfgqpc"]["sequence"])
            self.assertEqual(place.kfgqpc_text, entries[_id(*place.address)]["aya_text"])
        # hafs:1:2 opens a quarter: its KFGQPC range counts the sign and separator the table removed.
        self.assertEqual(trace.places[0].kfgqpc, (12, 13))
        self.assertEqual(trace.places[0].tanzil, (10, 11))

    def test_a_place_after_an_equivalence_points_into_the_published_text(self):
        # Word 1 holds a two-code-point KFGQPC sequence the table rewrites as one; a letter added later stays a difference.
        entries = self.entries_with_text(
            1, 4, lambda t: t.replace("\u064e", "\u06e1\u06e1").replace("\u0628\u064a", "\u0628x\u064a")
        )
        table = _table(_equivalence(["U+06E1", "U+06E1"], ["U+064E"], ["hafs:1:4"]))
        report, trace = self.traced(entries, table)
        (place,) = trace.places
        self.assertEqual(report["differences"][0]["kfgqpc"]["sequence"], ["U+0078"])
        self.assertEqual(place.kfgqpc_text[slice(*place.kfgqpc)], "x")
        # Two for the quarter sign and separator P-2 removed, one for the rewritten pair.
        self.assertEqual(place.kfgqpc[0], place.tanzil[0] + 3)

    def test_a_difference_inside_a_rewritten_sequence_covers_all_of_it(self):
        # The table rewrites the KFGQPC pair as two other code points; the Tanzil ayah has only the first.
        entries = self.entries_with_text(1, 4, lambda t: t.replace("\u064e", "\u06e1\u06e1"))
        table = _table(_equivalence(["U+06E1", "U+06E1"], ["U+064E", "U+0651"], ["hafs:1:4"]))
        report, trace = self.traced(entries, table)
        (place,) = trace.places
        self.assertEqual(report["differences"][0]["kfgqpc"]["sequence"], ["U+0651"])
        self.assertEqual(place.kfgqpc_text[slice(*place.kfgqpc)], "\u06e1\u06e1")

    def test_the_surah_openings_p3_accepts(self):
        _, trace = self.traced(synthetic.synthetic_kfgqpc_entries())
        self.assertEqual(trace.places, [])
        self.assertEqual(trace.surah_opening_quarters, [(1, 1), (2, 1), (3, 1)])


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
        table = self.work / "known_differences.json"
        table.write_bytes(json.dumps(synthetic_table_document()).encode("ascii"))
        text = read_tanzil_text(synthetic.synthetic_text_xml())
        metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml())
        tanzil = {"text": "a" * 64, "metadata": "b" * 64}
        report = compare.run_comparison(text, metadata, path, table, PROFILES["synthetic"], tanzil)
        self.assertEqual(report["format"], "holyquran-kfgqpc-comparison")
        self.assertEqual(report["tanzil"], {"text_sha256": "a" * 64, "metadata_sha256": "b" * 64})
        self.assertEqual(
            report["kfgqpc"],
            {
                "registry_row": 2,
                "file": "hafsData_v2-0.json",
                "version": "2.0 (update 13.0)",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            },
        )
        self.assertEqual(report["table"]["version"], 2)
        self.assertEqual(report["table"]["sha256"], hashlib.sha256(table.read_bytes()).hexdigest())
        self.assertTrue(report["passed"])


if __name__ == "__main__":
    unittest.main()
