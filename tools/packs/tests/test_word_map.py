"""Tanzil tokens to KFGQPC words, and timing re-indexed onto them, on the synthetic source only.

Token numbers are from 0, as quran-align counts them; KFGQPC words from 1. The
synthetic ayah 1:2 has the tokens word, U+06D6, word, U+06E9.
"""

import json
import unittest

import synthetic_source as synthetic
from hqpack import word_map
from hqpack.errors import PackError
from hqpack.known_differences import read_table
from hqpack.kfgqpc import read_kfgqpc
from hqpack.quran_align import OVERLAP, ZERO_LENGTH, Segment, Timing
from hqpack.tanzil_text import read_tanzil_text
from hqpack.word_map import AyahMap, Token, WordSegment, WordTiming

from tests.build_support import synthetic_table_document
from tests.test_cli import CliCase
from tests.build_support import hafs_shaped_profiles

NBSP = "\u00a0"
TOKENS = {(1, 1): 3, (1, 2): 4, (1, 3): 3, (1, 4): 2, (2, 1): 3, (2, 2): 5, (2, 3): 3, (3, 1): 3}


def _table(*rules):
    document = synthetic_table_document()
    document["rules"] += list(rules)
    return read_table(json.dumps(document).encode("ascii"))


def _entries(changes):
    """The synthetic KFGQPC entries with `changes` {(surah, ayah): function of aya_text}."""
    entries = synthetic.synthetic_kfgqpc_entries()
    for entry in entries:
        change = changes.get((entry["sura_no"], entry["aya_no"]))
        if change is not None:
            entry["aya_text"] = change(entry["aya_text"])
    return entries


def run_map(changes=None, table=None):
    text = read_tanzil_text(synthetic.synthetic_text_xml())
    witness = read_kfgqpc(synthetic.synthetic_kfgqpc_json(_entries(changes or {})), 8)
    return word_map.map_words(text, witness, _table() if table is None else table)


def joined(text):
    """KFGQPC writes the pause mark U+06D6 inside the word before it."""
    return text.replace(" \u06d6", "\u06d6")


def kinds(problems):
    return [(p["address"], p["kind"]) for p in problems]


class MapTest(unittest.TestCase):
    def test_equal_texts_map_every_word_to_the_same_word(self):
        maps, problems, counts = run_map()
        self.assertEqual(problems, [])
        self.assertEqual(sorted(maps), sorted(TOKENS))
        self.assertEqual(
            maps[(1, 2)],
            AyahMap(words=2, tokens=(Token(1, True), Token(None, False), Token(2, True), Token(None, False))),
        )
        self.assertEqual(maps[(1, 3)].tokens, (Token(None, False), Token(1, True), Token(2, True)))
        self.assertEqual(
            dict(counts),
            {
                "ayat": 8, "tanzil_tokens": 26, "tanzil_words": 21, "tanzil_marks": 5, "marks_joined": 0,
                "marks_apart": 5, "marks_unmatched": 0, "kfgqpc_words": 21,
            },
        )

    def test_a_mark_kfgqpc_writes_inside_a_word_goes_to_that_word(self):
        maps, problems, counts = run_map({(1, 2): joined})
        self.assertEqual(problems, [])
        self.assertEqual(maps[(1, 2)].tokens, (Token(1, True), Token(1, False), Token(2, True), Token(None, False)))
        self.assertEqual((counts["marks_joined"], counts["marks_apart"]), (1, 4))

    def test_a_mark_kfgqpc_lacks_goes_to_no_word(self):
        maps, problems, counts = run_map({(1, 2): lambda t: t.replace(" \u06d6", "")})
        self.assertEqual(problems, [])
        self.assertEqual(maps[(1, 2)].tokens[1], Token(None, False))
        self.assertEqual(counts["marks_unmatched"], 1)

    def test_a_letter_encoded_otherwise_still_maps(self):
        maps, problems, _ = run_map({(1, 4): lambda t: t.replace("\u064e", "\u06e1")})
        self.assertEqual(problems, [])
        self.assertEqual(maps[(1, 4)].tokens, (Token(1, True), Token(2, True)))

    def test_two_tanzil_words_in_one_kfgqpc_word_stop(self):
        maps, problems, _ = run_map({(1, 1): lambda t: t.replace("ayah one", "ayahone")})
        self.assertEqual(problems, [{"address": "hafs:1:1", "kind": "shared_word", "kfgqpc_word": 2, "tanzil_tokens": [1, 2]}])
        self.assertNotIn((1, 1), maps)

    def test_a_tanzil_word_kfgqpc_splits_is_ambiguous_and_leaves_words_unmapped(self):
        _, problems, _ = run_map({(3, 1): lambda t: t.replace("last", "la st")})
        self.assertEqual(
            problems,
            [
                {"address": "hafs:3:1", "kind": "ambiguous", "tanzil_token": 1},
                {"address": "hafs:3:1", "kind": "unmapped_word", "kfgqpc_word": 2},
                {"address": "hafs:3:1", "kind": "unmapped_word", "kfgqpc_word": 3},
            ],
        )

    def test_a_tanzil_word_kfgqpc_lacks_stops(self):
        _, problems, _ = run_map({(1, 1): lambda t: t.replace("ayah ", "")})
        self.assertEqual(problems, [{"address": "hafs:1:1", "kind": "unmatched_word", "tanzil_token": 1}])

    def test_a_kfgqpc_word_tanzil_lacks_stops(self):
        _, problems, _ = run_map({(1, 1): lambda t: t.replace("ayah", "ayah extra")})
        self.assertEqual(kinds(problems), [("hafs:1:1", "unmapped_word")])

    def test_a_tanzil_word_in_a_kfgqpc_mark_stops(self):
        _, problems, _ = run_map({(1, 4): lambda t: t.replace("\u0646\u064e\u0635", "\u064e")})
        self.assertEqual(problems, [{"address": "hafs:1:4", "kind": "word_in_mark", "tanzil_token": 0}])

    def test_the_map_follows_an_equivalence_back_to_the_kfgqpc_word(self):
        rule = {
            "id": "E-1", "kind": "equivalence", "code_points": {"kfgqpc": ["U+00A0"], "tanzil": ["U+0020"]},
            "applies_to": ["hafs:1:1"], "reason": "Synthetic rule for a test",
            "approved_by": "owner and proofreader (synthetic)", "date": "2026-01-01",
        }
        _, problems, _ = run_map({(1, 1): lambda t: t.replace("ayah one", "ayah" + NBSP + "one", 1)}, _table(rule))
        self.assertEqual(problems, [{"address": "hafs:1:1", "kind": "shared_word", "kfgqpc_word": 2, "tanzil_tokens": [1, 2]}])

    def test_an_ayah_whose_presentation_the_table_cannot_remove_stops(self):
        maps, problems, _ = run_map({(1, 1): lambda t: t[:-1] + chr(0xFC05)})
        self.assertEqual(problems, [{"address": "hafs:1:1", "kind": "presentation"}])
        self.assertNotIn((1, 1), maps)

    def test_texts_that_name_other_ayat_are_refused(self):
        text = read_tanzil_text(synthetic.synthetic_text_xml())
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[1]["aya_no"], entries[2]["aya_no"] = 3, 2
        with self.assertRaises(PackError):
            word_map.map_words(text, read_kfgqpc(synthetic.synthetic_kfgqpc_json(entries), 8), _table())


def _maps(changes=None):
    maps, problems, _ = run_map(changes)
    assert not problems
    return maps


def _reindex(segments, address=(1, 2), changes=None):
    timing = Timing(address[0], address[1], tuple(Segment(*s) for s in segments))
    return word_map.reindex({address: timing}, _maps(changes))


class ReindexTest(unittest.TestCase):
    def test_segments_go_to_the_kfgqpc_words_of_the_tanzil_words_they_cover(self):
        result, problems, counts = _reindex([(0, 2, 100, 200), (2, 4, 300, 400)])
        self.assertEqual(problems, [])
        self.assertEqual(
            result[(1, 2)], WordTiming(1, 2, (WordSegment(1, 1, 100, 200), WordSegment(2, 2, 300, 400)))
        )
        self.assertEqual(counts["merged_mark_segments"], 0)

    def test_a_segment_over_a_joined_mark_merges_into_the_word_s_segment(self):
        result, problems, counts = _reindex(
            [(0, 1, 100, 200), (1, 2, 200, 250, (ZERO_LENGTH,)), (2, 3, 300, 400)], changes={(1, 2): joined}
        )
        self.assertEqual(problems, [])
        self.assertEqual(
            result[(1, 2)].segments,
            (WordSegment(1, 1, 100, 250, (ZERO_LENGTH,)), WordSegment(2, 2, 300, 400)),
        )
        self.assertEqual((counts["segments"], counts["merged_mark_segments"], counts["kfgqpc_segments"]), (3, 1, 2))

    def test_merged_defects_keep_the_reader_s_order(self):
        result, _, _ = _reindex(
            [(0, 1, 100, 200, (ZERO_LENGTH,)), (1, 2, 150, 250, (OVERLAP,))], changes={(1, 2): joined}
        )
        self.assertEqual(result[(1, 2)].segments[0].defects, (OVERLAP, ZERO_LENGTH))

    def test_a_joined_mark_s_segment_with_no_segment_of_its_word_before_it_stops(self):
        result, problems, _ = _reindex([(1, 2, 200, 250), (2, 3, 300, 400)], changes={(1, 2): joined})
        self.assertEqual(problems, [{"address": "hafs:1:2", "kind": "lone_mark", "segment": 1, "kfgqpc_word": 1}])
        self.assertEqual(result, {})

    def test_a_segment_over_a_mark_kfgqpc_writes_apart_stops(self):
        _, problems, _ = _reindex([(0, 1, 100, 200), (3, 4, 300, 400)])
        self.assertEqual(problems, [{"address": "hafs:1:2", "kind": "no_word", "segment": 2}])

    def test_a_segment_past_the_ayah_s_tokens_stops(self):
        _, problems, _ = _reindex([(0, 5, 100, 200)])
        self.assertEqual(
            problems,
            [{"address": "hafs:1:2", "kind": "past_the_ayah", "segment": 1, "word_end": 5, "tanzil_tokens": 4}],
        )

    def test_an_ayah_without_timing_stays_without_timing(self):
        timing = Timing(1, 2, (), segments_field=False)
        result, problems, counts = word_map.reindex({(1, 2): timing}, {})
        self.assertEqual(problems, [])
        self.assertEqual(result[(1, 2)], WordTiming(1, 2, (), segments_field=False))
        self.assertEqual(counts["ayat_without_timing"], 1)

    def test_a_timed_ayah_without_a_map_stops(self):
        timing = Timing(1, 1, (Segment(0, 1, 100, 200),))
        result, problems, _ = word_map.reindex({(1, 1): timing}, {})
        self.assertEqual(problems, [{"address": "hafs:1:1", "kind": "unmapped_ayah"}])
        self.assertEqual(result, {})


def _timing_json(segments_of):
    return json.dumps(
        [
            {
                "surah": s, "ayah": a, "segments": segments_of(s, a, n),
                "stats": {"insertions": 0, "deletions": 0, "transpositions": 0},
            }
            for (s, a), n in sorted(TOKENS.items())
        ]
    ).encode("ascii")


class TimingMapCliTest(CliCase):
    def run_timing_map(self, *timings):
        self.write_source()
        paths = []
        for number, data in enumerate(timings, 1):
            path = self.work / ("timing-%d.json" % number)
            path.write_bytes(data)
            paths.extend(["--timing", path])
        with hafs_shaped_profiles():
            return self.run_cli(
                "timing-map",
                "--text", self.source / synthetic.TEXT_FILE,
                "--metadata", self.source / synthetic.METADATA_FILE,
                "--kfgqpc", self.write_kfgqpc(),
                "--table", self.write_table(),
                *paths,
            )

    def test_counts_and_a_pass_on_equal_texts_and_whole_ayah_segments(self):
        code, out, _ = self.run_timing_map(_timing_json(lambda s, a, n: [[0, n, 0, 1000]]))
        self.assertEqual(code, 0, out)
        self.assertIn(
            "word map: ayat 8, tanzil tokens 26, tanzil words 21, tanzil marks 5, marks joined 0, marks apart 5, "
            "marks unmatched 0, kfgqpc words 21",
            out,
        )
        self.assertRegex(out, r"timing 1 sha256 [0-9a-f]{64}: ayat 8, ayat without timing 0, segments 8, "
                              r"merged mark segments 0, kfgqpc segments 8")
        self.assertRegex(out, r"kfgqpc sha256 [0-9a-f]{64}")
        self.assertEqual(out.splitlines()[-1], "passed")

    def test_a_timing_problem_exits_65_with_its_kind_and_address(self):
        code, out, _ = self.run_timing_map(
            _timing_json(lambda s, a, n: [[3, 4, 0, 1000]] if (s, a) == (1, 2) else [[0, n, 0, 1000]])
        )
        self.assertEqual(code, 65, out)
        self.assertIn("problem no_word 1, first hafs:1:2", out)
        self.assertEqual(out.splitlines()[-1], "problems found: the timing cannot be put on KFGQPC words")


if __name__ == "__main__":
    unittest.main()
