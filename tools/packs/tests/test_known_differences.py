"""The table of known differences: the shipped file and every refusal of the reader."""

import copy
import json
import unittest
from pathlib import Path

from hqpack.errors import PackError
from hqpack.known_differences import (
    AYAH_END,
    EQUIVALENCE,
    EVERY_AYAH,
    PRESENTATION,
    QUARTER_START,
    read_table,
)

SHIPPED = Path(__file__).resolve().parents[1] / "known_differences.json"
LEAD_PRESENTATION = "lead (presentation, D-175)"

EQUIVALENCE_RULE = {
    "id": "E-1",
    "kind": "equivalence",
    "code_points": {"kfgqpc": ["U+06E1"], "tanzil": ["U+0652"]},
    "applies_to": ["hafs:1:2", "hafs:2:1"],
    "reason": "Synthetic rule for a test",
    "approved_by": "owner and proofreader (synthetic)",
    "date": "2026-01-01",
}


def _document():
    return json.loads(SHIPPED.read_text(encoding="ascii"))


def _bytes(document):
    return json.dumps(document).encode("ascii")


class ShippedTableTest(unittest.TestCase):
    def setUp(self):
        self.table = read_table(SHIPPED.read_bytes())

    def test_it_is_ascii(self):
        self.assertTrue(SHIPPED.read_bytes().isascii())

    def test_it_holds_the_two_presentation_rules_only(self):
        self.assertEqual(self.table.version, 1)
        self.assertEqual(self.table.equivalences, ())
        end, quarter = self.table.ayah_end, self.table.quarter_start
        self.assertEqual((end.kind, end.applies_to), (PRESENTATION, AYAH_END))
        self.assertEqual(end.code_points, {"separator": 0x00A0, "first_number_glyph": 0xFC00})
        self.assertEqual((quarter.kind, quarter.applies_to), (PRESENTATION, QUARTER_START))
        self.assertEqual(quarter.code_points, {"sign": 0x06DE, "separator": 0x00A0})

    def test_the_lead_approved_presentation_only(self):
        for rule in _document()["rules"]:
            if rule["approved_by"] == LEAD_PRESENTATION:
                self.assertEqual(rule["kind"], PRESENTATION, rule["id"])


class TableReaderTest(unittest.TestCase):
    def assert_refused(self, pattern, document=None, data=None):
        data = _bytes(document) if data is None else data
        with self.assertRaises(PackError) as caught:
            read_table(data)
        self.assertRegex(str(caught.exception), pattern)
        self.assertTrue(str(caught.exception).isascii())

    def with_rule(self, rule):
        document = _document()
        document["rules"].append(rule)
        return document

    def changed(self, index, **fields):
        document = _document()
        document["rules"][index].update(fields)
        return document

    def test_an_equivalence_is_read(self):
        table = read_table(_bytes(self.with_rule(dict(EQUIVALENCE_RULE))))
        (rule,) = table.equivalences
        self.assertEqual(rule.kind, EQUIVALENCE)
        self.assertEqual(rule.applies_to, ((1, 2), (2, 1)))
        self.assertEqual(rule.code_points, {"kfgqpc": (0x06E1,), "tanzil": (0x0652,)})
        every = dict(EQUIVALENCE_RULE, applies_to=EVERY_AYAH, code_points={"kfgqpc": ["U+06E1"], "tanzil": []})
        self.assertEqual(read_table(_bytes(self.with_rule(every))).equivalences[0].applies_to, EVERY_AYAH)

    def test_a_byte_outside_ascii(self):
        self.assert_refused("outside ASCII", data=SHIPPED.read_bytes().replace(b"Tanzil", "Tanz\u0131l".encode("utf-8"), 1))

    def test_invalid_json_and_constants(self):
        self.assert_refused("invalid JSON at line", data=b"{")
        self.assert_refused("NaN", data=b'{"format": NaN}')
        self.assert_refused("repeats a key", data=b'{"format": 1, "format": 2}')

    def test_the_top_level(self):
        for change, pattern in (
            (lambda d: d.update(format="other"), "format is not holyquran-known-differences"),
            (lambda d: d.update(version=0), "version is not a positive integer"),
            (lambda d: d.update(version=True), "version is not a positive integer"),
            (lambda d: d.update(rules={}), "rules is not an array"),
            (lambda d: d.pop("version"), "lacks version"),
            (lambda d: d.update(extra=1), "has a key other than"),
        ):
            document = _document()
            change(document)
            with self.subTest(pattern=pattern):
                self.assert_refused(pattern, document)

    def test_rule_fields(self):
        for fields, pattern in (
            ({"id": "P 1"}, "rule 1: id is not"),
            ({"id": 1}, "rule 1: id is not"),
            ({"kind": "other"}, "kind is not presentation or equivalence"),
            ({"reason": " "}, "reason is empty"),
            ({"approved_by": None}, "approved_by is empty or not a string"),
            ({"date": "2026-1-6"}, "date is not YYYY-MM-DD"),
            ({"applies_to": "every_ayah"}, "a presentation rule applies to ayah_end or quarter_start"),
            ({"code_points": {"separator": "U+00A0"}}, "code_points lacks first_number_glyph"),
            ({"code_points": {"sign": "U+06DE", "separator": "U+00A0"}}, "code_points lacks"),
        ):
            with self.subTest(fields=fields):
                self.assert_refused(pattern, self.changed(0, **fields))

    def test_code_point_strings(self):
        for value in ("U+A0", "u+00A0", "U+00a0", "U+D800", "U+110000", "U+0000A0", 160, "\u00a0"):
            with self.subTest(value=value):
                document = self.changed(0, code_points={"separator": value, "first_number_glyph": "U+FC00"})
                self.assert_refused("separator holds", document)

    def test_a_missing_or_extra_rule_key(self):
        rule = dict(EQUIVALENCE_RULE)
        del rule["reason"]
        self.assert_refused("rule 3 lacks reason", self.with_rule(rule))
        self.assert_refused("rule 3 has a key other than", self.with_rule(dict(EQUIVALENCE_RULE, note="x")))

    def test_duplicates(self):
        self.assert_refused("two rules share an id", self.with_rule(dict(EQUIVALENCE_RULE, id="P-1")))
        twin = copy.deepcopy(_document()["rules"][0])
        twin["id"] = "P-9"
        self.assert_refused("rules P-1 and P-9 are both presentation at ayah_end", self.with_rule(twin))

    def test_equivalence_refusals(self):
        for fields, pattern in (
            ({"code_points": {"kfgqpc": [], "tanzil": ["U+0652"]}}, "the kfgqpc sequence is empty"),
            ({"code_points": {"kfgqpc": ["U+0652"], "tanzil": ["U+0652"]}}, "the two sequences are equal"),
            ({"code_points": {"kfgqpc": "U+06E1", "tanzil": ["U+0652"]}}, "code_points.kfgqpc is not an array"),
            ({"applies_to": []}, "applies_to is not every_ayah or a list"),
            ({"applies_to": "everywhere"}, "applies_to is not every_ayah or a list"),
            ({"applies_to": ["hafs:2:1", "hafs:1:2"]}, "not sorted and unique"),
            ({"applies_to": ["hafs:1:2", "hafs:1:2"]}, "not sorted and unique"),
            ({"applies_to": ["hafs:1:02"]}, "not hafs:S:A"),
            ({"applies_to": ["warsh:1:2"]}, "not hafs:S:A"),
            ({"applies_to": ["hafs:0:2"]}, "not hafs:S:A"),
            ({"approved_by": "Lead, after review"}, "approved by the owner and his proofreader, not the lead"),
            ({"approved_by": LEAD_PRESENTATION}, "not the lead"),
        ):
            with self.subTest(fields=fields):
                self.assert_refused(pattern, self.with_rule(dict(EQUIVALENCE_RULE, **fields)))


if __name__ == "__main__":
    unittest.main()
