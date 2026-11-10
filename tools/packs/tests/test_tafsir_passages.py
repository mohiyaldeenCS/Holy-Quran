"""D-186 and D-184: the gate, ranges, merging, order and numbering, on synthetic entries."""

from __future__ import annotations

import re
import unittest
from types import SimpleNamespace

from hqpack.errors import PackError
from hqpack.tafsir_database import PassageRow
from hqpack.tafsir_passages import assemble, select

COUNTS = {1: 7, 2: 5, 3: 1}


def review(cleared=(), excluded=()):
    return SimpleNamespace(cleared=set(cleared), excluded=set(excluded))


def entries(*specs):
    """(kind, surah, refs[, flags]) in book order; n is the position."""
    found = []
    for n, spec in enumerate(specs, 1):
        kind, surah, refs = spec[:3]
        entry = {
            "n": n,
            "kind": kind,
            "surah": surah,
            "refs": refs,
            "paragraphs": [{"site_page": 100 + n, "html": "<p>synthetic %d</p>" % n}],
        }
        if len(spec) > 3:
            entry["review"] = spec[3]
        found.append(entry)
    return found


def outcomes(listed, default="same"):
    return {e["n"]: default for e in listed if e["kind"] == "passage"}


def build(listed, found=None, given=None, counts=COUNTS):
    selection = select(listed, outcomes(listed) if found is None else found, given or review(), counts)
    texts = {c.n: ["Synthetic %d" % c.n] for c in selection.chosen}
    return selection, assemble(selection.chosen, texts)


class GateTest(unittest.TestCase):
    def test_each_outcome_of_the_gate(self):
        listed = entries(*[("passage", 1, [[n, n]]) for n in range(1, 8)])
        found = {
            1: "same",
            2: "same_but_for_spelling",
            3: "too_short_to_compare",
            4: "no_quotation",
            5: "in_a_neighbouring_ayah",
            6: "partly_found",
            7: "not_found",
        }
        selection, rows = build(listed, found)
        self.assertEqual([c.n for c in selection.chosen], [1, 2])
        self.assertEqual(
            [(h.n, h.site_page, h.reason) for h in selection.held],
            [
                (3, 103, "too_short_to_compare"),
                (4, 104, "no_quotation"),
                (5, 105, "in_a_neighbouring_ayah"),
                (6, 106, "partly_found"),
                (7, 107, "not_found"),
            ],
        )
        self.assertEqual(len(rows), 2)

    def test_a_flag_holds_a_confirmed_entry_and_clearing_ships_it(self):
        listed = entries(("passage", 1, [[1, 1]], ["ayah_number_out_of_order"]), ("passage", 1, [[2, 2]]))
        found = {1: "same", 2: "not_found"}
        selection = select(listed, found, review(), COUNTS)
        self.assertEqual([(h.n, h.reason) for h in selection.held], [(1, "flagged"), (2, "not_found")])
        self.assertEqual(selection.chosen, [])
        selection, rows = build(listed, found, review(cleared=[1, 2]))
        self.assertEqual(selection.held, [])
        self.assertEqual([(r.first_ayah, r.last_ayah) for r in rows], [(1, 1), (2, 2)])

    def test_an_exclusion_overrides_a_clearance_and_a_confirmation(self):
        listed = entries(("passage", 1, [[1, 1]]), ("passage", 1, [[2, 2]]), ("unlinked", 1, []), ("passage", 1, [[3, 3]]))
        selection, rows = build(listed, given=review(cleared=[2], excluded=[1, 2, 3]))
        self.assertEqual([(h.n, h.reason) for h in selection.held], [(1, "excluded"), (2, "excluded"), (3, "excluded")])
        self.assertEqual([r.first_ayah for r in rows], [3])

    def test_kinds_that_never_ship(self):
        listed = entries(
            ("heading", 1, []),
            ("text", 1, [[1, 7]]),
            ("title_page", None, []),
            ("ornament", None, []),
            ("footnote", 1, []),
            ("unlinked", None, []),
            ("passage", 1, [[1, 1]]),
        )
        selection, rows = build(listed)
        self.assertEqual([c.n for c in selection.chosen], [7])
        self.assertEqual(
            dict(selection.never),
            {"heading": 1, "text": 1, "title_page": 1, "ornament": 1, "footnote": 1, "unlinked": 1},
        )
        self.assertEqual(len(rows), 1)

    def test_a_flagged_surah_level_entry_is_held_until_cleared(self):
        listed = entries(("unlinked", 2, [], ["synthetic_flag"]), ("passage", 2, [[1, 1]]))
        selection, rows = build(listed)
        self.assertEqual([(h.n, h.reason) for h in selection.held], [(1, "flagged")])
        selection, rows = build(listed, given=review(cleared=[1]))
        self.assertEqual([(r.surah, r.first_ayah, r.last_ayah) for r in rows], [(2, 0, 0), (2, 1, 1)])


class RangeTest(unittest.TestCase):
    def test_a_gapped_range_is_held_out(self):
        listed = entries(("passage", 1, [[1, 2], [4, 4]]), ("passage", 1, [[5, 6], [7, 7]]))
        selection, rows = build(listed)
        self.assertEqual([(h.n, h.reason) for h in selection.held], [(1, "gapped_range")])
        self.assertEqual([(r.first_ayah, r.last_ayah) for r in rows], [(5, 7)])

    def test_ranges_outside_their_surah_stop_the_build(self):
        cases = (
            (("passage", 1, [[0, 2]]), "entry 1: range 0..2 of surah 1 starts below ayah 1"),
            (("passage", 1, [[3, 2]]), "entry 1: range 3..2 of surah 1 is reversed"),
            (("passage", 3, [[1, 2]]), "entry 1 reaches ayah 2 of surah 3, which has 1"),
            (("passage", 4, [[1, 1]]), "entry 1: surah 4 is not a surah of the ayah counts (1 to 3)"),
            (("unlinked", 4, []), "entry 1: surah 4 is not a surah of the ayah counts (1 to 3)"),
            (("passage", None, [[1, 1]]), "entry 1 is linked to ayat but names no surah"),
            (("passage", 1, []), "entry 1 is linked to ayat but has no range"),
        )
        for spec, expected in cases:
            with self.subTest(expected=expected):
                with self.assertRaisesRegex(PackError, re.escape(expected)):
                    build(entries(spec))

    def test_a_range_is_checked_only_when_its_entry_ships(self):
        selection, _ = build(entries(("passage", 1, [[1, 9]]), ("passage", 1, [[1, 1]])), {1: "not_found", 2: "same"})
        self.assertEqual([(h.n, h.reason) for h in selection.held], [(1, "not_found")])


class MergeAndOrderTest(unittest.TestCase):
    def test_overlapping_and_equal_ranges_merge_in_book_order(self):
        listed = entries(
            ("passage", 1, [[3, 4]]),
            ("passage", 1, [[1, 3]]),
            ("passage", 1, [[1, 3]]),
            ("passage", 1, [[4, 6]]),
        )
        _, rows = build(listed)
        self.assertEqual(rows, [PassageRow(1, 1, 1, 6, "Synthetic 1\nSynthetic 2\nSynthetic 3\nSynthetic 4")])

    def test_touching_ranges_do_not_merge(self):
        _, rows = build(entries(("passage", 1, [[1, 2]]), ("passage", 1, [[3, 4]])))
        self.assertEqual([(r.first_ayah, r.last_ayah, r.text) for r in rows], [(1, 2, "Synthetic 1"), (3, 4, "Synthetic 2")])

    def test_reverse_book_order_is_sorted_into_mushaf_order_and_numbered(self):
        listed = entries(
            ("passage", 3, [[1, 1]]),
            ("unlinked", 2, []),
            ("passage", 2, [[4, 5]]),
            ("passage", 2, [[1, 2]]),
            ("unlinked", 2, []),
            ("passage", 1, [[7, 7]]),
            ("unlinked", 1, []),
        )
        _, rows = build(listed)
        self.assertEqual(
            rows,
            [
                PassageRow(1, 1, 0, 0, "Synthetic 7"),
                PassageRow(2, 1, 7, 7, "Synthetic 6"),
                PassageRow(3, 2, 0, 0, "Synthetic 2\nSynthetic 5"),
                PassageRow(4, 2, 1, 2, "Synthetic 4"),
                PassageRow(5, 2, 4, 5, "Synthetic 3"),
                PassageRow(6, 3, 1, 1, "Synthetic 1"),
            ],
        )

    def test_empty_paragraphs_are_left_out_of_the_join(self):
        listed = entries(("passage", 1, [[1, 1]]), ("passage", 1, [[1, 1]]))
        selection = select(listed, outcomes(listed), review(), COUNTS)
        rows = assemble(selection.chosen, {1: [], 2: ["Synthetic b"]})
        self.assertEqual(rows[0].text, "Synthetic b")
        with self.assertRaisesRegex(PackError, "entries 1, 2 of surah 1 have no text after conversion"):
            assemble(selection.chosen, {1: [], 2: []})

    def test_zero_passages_is_refused(self):
        listed = entries(("heading", 1, []), ("passage", 1, [[1, 1]], ["synthetic_flag"]))
        with self.assertRaisesRegex(PackError, "no passage is left to ship"):
            build(listed)


if __name__ == "__main__":
    unittest.main()
