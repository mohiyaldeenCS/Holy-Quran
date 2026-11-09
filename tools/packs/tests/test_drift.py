"""The recitation drift tool, on synthetic MP3 bytes, synthetic timing and the synthetic Tanzil source."""

import json
import unittest
from dataclasses import replace
from pathlib import Path

import synthetic_source as synthetic
from hqpack import digest, drift
from hqpack.errors import PackError
from hqpack.mp3 import read_mp3
from hqpack.profiles import PROFILES
from hqpack.quran_align import Segment, Timing, read_timing
from hqpack.tanzil_metadata import read_tanzil_metadata
from hqpack.tanzil_text import read_tanzil_text

from tests import mp3_factory as f
from tests.build_support import REPO, BuildCase, hafs_shaped_profiles
from tests.test_cli import CliCase

SYNTHETIC = PROFILES["synthetic"]
EDITION = "Test_Edition_64kbps"
AYAT = [(s, a) for s, (count, *_rest) in enumerate(synthetic.SYNTHETIC_SURAS, 1) for a in range(1, count + 1)]

# MPEG 1, 32 kHz, mono, no info frame: granule i starts at 18 * i ms. Speech
# from 180 to 720 ms and from 900 to 1,440 ms; 1,512 ms in all.
TWO_RUNS = f.pattern((f.SILENT, 10), (f.LOUD, 30), (f.SILENT, 10), (f.LOUD, 30), (f.SILENT, 4))
TWO_RUNS_MS = 1512.0


def segments(shift=0, end_shift=None):
    """Two segments around the one pause of TWO_RUNS, both moved `shift` ms; the last end by `end_shift`."""
    last = 1440 + (shift if end_shift is None else end_shift)
    return [[0, 1, 180 + shift, 720 + shift], [1, 2, 900 + shift, last]]


# A third run 9 s after the first pause: speech 900 to 9,720 ms, pause to 9,900 ms, speech to 10,440 ms.
THREE_RUNS = f.pattern(
    (f.SILENT, 10), (f.LOUD, 30), (f.SILENT, 10), (f.LOUD, 490), (f.SILENT, 10), (f.LOUD, 30), (f.SILENT, 4)
)


def three_segments(later):
    """The second boundary `later` ms after its pause, the first on its pause: slope later / 0.15 ms per minute."""
    return [[0, 1, 180, 720], [1, 2, 900, 9720 + later], [2, 3, 9900 + later, 10440]]


ABSENT = object()


def timing_json(overrides=None, default=None, drop=(), extra=()):
    """The timing of every synthetic ayah; an override of ABSENT leaves out the entry's `segments` field."""
    overrides = overrides or {}
    entries = []
    for address in reversed(AYAT):
        if address in drop:
            continue
        entry = {
            "surah": address[0],
            "ayah": address[1],
            "segments": overrides.get(address, segments() if default is None else default),
            "stats": {"insertions": 0, "deletions": 1, "transpositions": 0},
        }
        if entry["segments"] is ABSENT:
            del entry["segments"]
        entries.append(entry)
    entries.extend(extra)
    return json.dumps(entries).encode("ascii")


def audio(levels):
    return read_mp3(f.stream(levels))


class SpeechTest(unittest.TestCase):
    def test_onset_and_pause(self):
        found = drift.speech(audio(TWO_RUNS))
        self.assertEqual(found.onset_ms, 180.0)
        self.assertEqual(found.pauses, ((720.0, 900.0),))

    def test_the_lame_delay_moves_the_granules(self):
        data = f.info_frame(frames=42, delay=47, padding=1105) + f.stream(TWO_RUNS)
        found = drift.speech(read_mp3(data))
        self.assertEqual(found.onset_ms, 162.0)
        self.assertEqual(found.pauses, ((702.0, 882.0),))

    def test_the_threshold_is_the_loud_level_less_twenty_steps(self):
        # 60 of 84 granules are loud (170), so the 90th percentile is 170 and the threshold 150.
        for level, pauses in (((10, 150), 1), ((10, 151), 0), (f.QUIET, 1), ((0, 250), 1)):
            with self.subTest(level=level):
                levels = f.pattern((f.SILENT, 10), (f.LOUD, 30), (level, 10), (f.LOUD, 30), (f.SILENT, 4))
                self.assertEqual(len(drift.speech(audio(levels)).pauses), pauses)

    def test_the_threshold_follows_the_file(self):
        quiet_speech = (300, 120)
        levels = f.pattern((f.SILENT, 10), (quiet_speech, 30), ((10, 99), 10), (quiet_speech, 30), (f.SILENT, 4))
        found = drift.speech(audio(levels))
        self.assertEqual((found.onset_ms, found.pauses), (180.0, ((720.0, 900.0),)))

    def test_the_loud_level_is_the_90th_percentile(self):
        # 30 of 84 granules are loud: the 90th percentile is loud, the median a quiet granule.
        levels = f.pattern((f.QUIET, 40), (f.LOUD, 15), (f.QUIET, 10), (f.LOUD, 15), (f.QUIET, 4))
        found = drift.speech(audio(levels))
        self.assertEqual((found.onset_ms, found.pauses), (720.0, ((990.0, 1170.0),)))

    def test_granule_level(self):
        self.assertEqual(drift.granule_level(((0, 200), (5, 90))), 90)
        self.assertEqual(drift.granule_level(((0, 200), (0, 90))), 0)
        self.assertEqual(drift.granule_level(((3, 100), (5, 90))), 100)

    def test_a_short_burst_is_silence(self):
        blip = f.pattern((f.SILENT, 4), (f.LOUD, 2), (f.SILENT, 4))
        levels = f.pattern((f.SILENT, 8), (f.LOUD, 2), (f.SILENT, 2), (f.LOUD, 30))
        levels += blip + f.pattern((f.LOUD, 30), (f.SILENT, 4))
        found = drift.speech(audio(levels))
        self.assertEqual(found.onset_ms, 216.0)
        self.assertEqual(found.pauses, ((756.0, 936.0),))
        longer = f.pattern((f.SILENT, 4), (f.LOUD, 3), (f.SILENT, 3))
        levels = f.pattern((f.SILENT, 10), (f.LOUD, 30)) + longer + f.pattern((f.LOUD, 30), (f.SILENT, 4))
        self.assertEqual(drift.speech(audio(levels)).pauses, ())

    def test_a_pause_lasts_at_least_120_ms(self):
        for silent, pauses in ((6, ()), (7, ((720.0, 846.0),))):
            levels = f.pattern(
                (f.SILENT, 10), (f.LOUD, 30), (f.SILENT, silent), (f.LOUD, 30), (f.SILENT, 4 + 10 - silent)
            )
            self.assertEqual(drift.speech(audio(levels)).pauses, pauses)

    def test_silence_at_either_end_is_no_pause(self):
        found = drift.speech(audio(f.pattern((f.SILENT, 20), (f.LOUD, 30), (f.SILENT, 20))))
        self.assertEqual((found.onset_ms, found.pauses), (360.0, ()))

    def test_a_silent_file(self):
        found = drift.speech(audio(f.pattern((f.SILENT, 10))))
        self.assertEqual((found.onset_ms, found.pauses), (None, ()))


class OffsetTest(unittest.TestCase):
    def test_the_sign_and_size_at_a_gap_and_a_join(self):
        gap = (Segment(0, 1, 0, 700), Segment(1, 2, 900, 1500))
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], gap), [(810.0, -10.0)])
        join = (Segment(0, 1, 0, 850), Segment(1, 2, 850, 1500))
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], join), [(810.0, 40.0)])

    def test_the_nearest_boundary(self):
        segs = (Segment(0, 1, 0, 500), Segment(1, 2, 500, 1000), Segment(2, 3, 1100, 2000), Segment(3, 4, 2000, 2500))
        self.assertEqual(
            drift.pause_offsets([(900.0, 1100.0), (1800.0, 2100.0)], segs), [(1000.0, 50.0), (1950.0, 50.0)]
        )

    def test_a_boundary_next_to_a_defective_segment_gives_no_sample(self):
        sound = (Segment(0, 1, 0, 800), Segment(1, 2, 820, 1500), Segment(2, 3, 2000, 2500))
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], sound), [(810.0, 0.0)])
        for kinds in (("zero_length",), ("end_before_start",), ("end_before_start", "overlap")):
            for index, samples in ((0, [(810.0, 940.0)]), (1, [])):
                with self.subTest(kinds=kinds, index=index):
                    segs = list(sound)
                    segs[index] = replace(segs[index], defects=kinds)
                    self.assertEqual(drift.pause_offsets([(720.0, 900.0)], segs), samples)
        overlapping = (sound[0], Segment(1, 2, 790, 1500, ("overlap",)))
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], overlapping), [])

    def test_no_boundary_no_sample(self):
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], (Segment(0, 3, 0, 1500),)), [])
        self.assertEqual(drift.pause_offsets([(720.0, 900.0)], ()), [])

    def test_slope(self):
        self.assertEqual(drift.slope_ms_per_minute([[(0.0, 0.0), (60000.0, 50.0)]]), 50.0)
        self.assertAlmostEqual(drift.slope_ms_per_minute([[(0.0, 10.0), (30000.0, 0.0), (60000.0, -10.0)]]), -20.0)
        two_files = [[(0.0, 0.0), (6000.0, 5.0)], [(0.0, 0.0), (6000.0, 3.0)]]
        self.assertAlmostEqual(drift.slope_ms_per_minute(two_files), 40.0)
        self.assertIsNone(drift.slope_ms_per_minute([[(1000.0, 5.0)], [(2000.0, 9.0)], []]))
        self.assertIsNone(drift.slope_ms_per_minute([[(1000.0, 5.0), (1000.0, 9.0)]]))

    def test_an_offset_that_differs_between_files_is_no_slope(self):
        files = [[(0.0, 100.0), (6000.0, 100.0)], [(54000.0, 0.0), (60000.0, 0.0)]]
        self.assertEqual(drift.slope_ms_per_minute(files), 0.0)

    def test_measure_file(self):
        timing = Timing(1, 1, tuple(Segment(*s) for s in segments(shift=25)))
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)
        self.assertEqual(result["address"], "hafs:1:1")
        self.assertEqual((result["duration_ms"], result["timing_end_ms"], result["end_check"]), (1512.0, 1465, "pass"))
        self.assertEqual((result["speech_onset_ms"], result["onset_ms"]), (180.0, 25.0))
        self.assertEqual(result["samples"], [{"at_ms": 810.0, "offset_ms": 25.0}])

    def test_the_end_check_allows_one_frame(self):
        for end, check in ((1548, "pass"), (1549, "fail")):
            timing = Timing(1, 1, tuple(Segment(*s) for s in segments(end_shift=end - 1440)))
            self.assertEqual(drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)["end_check"], check)

    def test_the_end_check_uses_the_last_sound_segment(self):
        late = Segment(2, 3, 9000, 8000, ("end_before_start",))
        timing = Timing(1, 1, tuple(Segment(*s) for s in segments()) + (late,))
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)
        self.assertEqual((result["timing_end_ms"], result["end_check"]), (1440, "pass"))
        self.assertEqual((result["segments"], result["defective_segments"]), (3, 1))
        past = Segment(0, 1, 180, 1600)
        timing = Timing(1, 1, (past, Segment(1, 2, 1600, 1600, ("zero_length",))))
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)
        self.assertEqual((result["timing_end_ms"], result["end_check"]), (1600, "fail"))

    def test_the_onset_uses_the_first_sound_segment(self):
        first = Segment(0, 1, 50, 50, ("zero_length",))
        timing = Timing(1, 1, (first,) + tuple(Segment(*s) for s in segments(shift=25)))
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)
        self.assertEqual(result["onset_ms"], 25.0)
        self.assertEqual(result["samples"], [{"at_ms": 810.0, "offset_ms": 25.0}])

    def test_a_file_whose_segments_are_all_defective(self):
        defective = (Segment(0, 1, 900, 100, ("end_before_start",)), Segment(1, 2, 950, 950, ("zero_length",)))
        timing = Timing(1, 1, defective)
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), timing)
        self.assertEqual(
            (result["timing_end_ms"], result["end_check"], result["onset_ms"], result["samples"]),
            (None, "not made", None, []),
        )


def _summary(**changes):
    summary = {
        "end_check_failures": 0,
        "median_offset_ms": 0.0,
        "p95_abs_offset_ms": 0.0,
        "slope_ms_per_minute": 0.0,
    }
    summary.update(changes)
    return summary


class VerdictTest(unittest.TestCase):
    def test_each_criterion_at_its_limit(self):
        self.assertEqual(drift.verdict(_summary()), [])
        for changes in (
            {"median_offset_ms": 100.0},
            {"median_offset_ms": -100.0},
            {"p95_abs_offset_ms": 250.0},
            {"slope_ms_per_minute": 50.0},
            {"slope_ms_per_minute": -50.0},
        ):
            self.assertEqual(drift.verdict(_summary(**changes)), [], changes)

    def test_each_criterion_missed(self):
        for changes, words in (
            ({"end_check_failures": 1}, "end check: 1 files"),
            ({"median_offset_ms": 100.1}, "median offset: |100.1| ms is above 100 ms"),
            ({"median_offset_ms": -100.1}, "median offset: |-100.1| ms is above 100 ms"),
            ({"median_offset_ms": None}, "median offset: no pause sample"),
            ({"p95_abs_offset_ms": 250.1}, "p95 |offset|: 250.1 ms is above 250 ms"),
            ({"p95_abs_offset_ms": None}, "p95 |offset|: no pause sample"),
            ({"slope_ms_per_minute": 50.1}, "slope: |50.1| ms per minute is above 50"),
            ({"slope_ms_per_minute": -50.1}, "slope: |-50.1| ms per minute is above 50"),
            ({"slope_ms_per_minute": None}, "slope: no file has two pause samples"),
        ):
            missed = drift.verdict(_summary(**changes))
            self.assertEqual(len(missed), 1, changes)
            self.assertIn(words, missed[0])

    def test_every_criterion_missed_is_named(self):
        missed = drift.verdict(
            _summary(end_check_failures=2, median_offset_ms=300.0, p95_abs_offset_ms=400.0, slope_ms_per_minute=90.0)
        )
        self.assertEqual([m.split(":")[0] for m in missed], ["end check", "median offset", "p95 |offset|", "slope"])

    def test_summarise(self):
        def file(samples, onset, check="pass"):
            listed = [{"at_ms": t, "offset_ms": o} for t, o in samples]
            return {"end_check": check, "onset_ms": onset, "samples": listed}

        files = [
            file([(1000.0, -5.0), (2000.0, 7.0)], 12.0),
            file([(1000.0, 3.0)] * 17 + [(2000.0, 260.0), (3000.0, -300.0)], -40.0, "fail"),
            file([], None),
            file([], None, "not made"),
        ]
        summary = drift.summarise(files, 8, 2)
        counts = (
            summary["files_measured"],
            summary["files_without_timing"],
            summary["entries_without_file"],
            summary["end_check_failures"],
            summary["end_checks_not_made"],
        )
        self.assertEqual(counts, (4, 2, 2, 1, 1))
        self.assertEqual((summary["onset_median_ms"], summary["onset_max_abs_ms"]), (-14.0, 40.0))
        self.assertEqual(summary["pause_samples"], 21)
        self.assertEqual(summary["median_offset_ms"], 3.0)
        self.assertEqual(summary["p95_abs_offset_ms"], 260.0)
        self.assertEqual(summary["max_abs_offset_ms"], 300.0)
        self.assertEqual(summary["verdict"], "FAIL")
        self.assertEqual([m.split(":")[0] for m in summary["missed"]], ["end check", "p95 |offset|", "slope"])


class TimingTest(unittest.TestCase):
    def setUp(self):
        self.metadata = read_tanzil_metadata(synthetic.synthetic_metadata_xml())

    def test_every_entry_in_any_order(self):
        timings = read_timing(timing_json(), SYNTHETIC, self.metadata)
        self.assertEqual(sorted(timings), AYAT)
        self.assertEqual(timings[(1, 2)].segments, (Segment(0, 1, 180, 720), Segment(1, 2, 900, 1440)))
        self.assertEqual(sorted(read_timing(timing_json(), SYNTHETIC)), AYAT)

    def test_empty_segments_and_touching_segments(self):
        data = timing_json({(1, 1): [], (1, 2): [[0, 1, 0, 500], [1, 3, 500, 600], [5, 6, 600, 900]]})
        timings = read_timing(data, SYNTHETIC)
        self.assertEqual((timings[(1, 1)].segments, timings[(1, 1)].segments_field), ((), True))
        self.assertEqual([s.defects for s in timings[(1, 2)].segments], [(), (), ()])
        self.assertEqual(len(timings[(1, 2)].sound()), 3)

    def test_an_entry_without_the_segments_field_is_an_ayah_without_timing(self):
        timings = read_timing(timing_json({(2, 2): ABSENT}), SYNTHETIC, self.metadata)
        self.assertEqual((timings[(2, 2)].segments, timings[(2, 2)].segments_field), ((), False))
        self.assertEqual(timings[(2, 1)].segments_field, True)

    def test_each_defect_kind_is_kept_and_marked(self):
        for segs, defects in (
            ([[0, 1, 9, 8]], [("end_before_start",)]),
            ([[0, 1, 9, 9]], [("zero_length",)]),
            ([[0, 1, 0, 500], [1, 2, 499, 900]], [(), ("overlap",)]),
            ([[0, 1, 0, 500], [1, 2, 450, 400]], [(), ("end_before_start", "overlap")]),
            ([[0, 1, 0, 500], [1, 2, 450, 450]], [(), ("overlap", "zero_length")]),
            ([[0, 1, 900, 100], [1, 2, 200, 300]], [("end_before_start",), ()]),
            ([[0, 1, 0, 900], [1, 2, 950, 940], [2, 3, 945, 990]], [(), ("end_before_start",), ()]),
            ([[0, 1, 0, 900], [1, 2, 800, 950], [2, 3, 940, 990]], [(), ("overlap",), ("overlap",)]),
            # Overlap is against the segment just before, not the latest end so far.
            ([[0, 1, 0, 900], [1, 2, 950, 100], [2, 3, 500, 990]], [(), ("end_before_start",), ()]),
        ):
            with self.subTest(segs=segs):
                timing = read_timing(timing_json({(2, 2): segs}), SYNTHETIC, self.metadata)[(2, 2)]
                self.assertEqual([s.defects for s in timing.segments], defects)
                self.assertEqual([[s.word_start, s.word_end, s.start_ms, s.end_ms] for s in timing.segments], segs)
                self.assertEqual(timing.sound(), tuple(s for s, d in zip(timing.segments, defects) if not d))

    def assert_refused(self, data, words, metadata=None):
        with self.assertRaises(PackError) as caught:
            read_timing(data, SYNTHETIC, metadata)
        self.assertIn(words, str(caught.exception))
        self.assertTrue(str(caught.exception).startswith("timing: "))

    def test_the_file(self):
        self.assert_refused(b"\xef\xbb\xbf" + timing_json(), "BOM")
        self.assert_refused(b'[{"surah": "\xff"}]', "malformed UTF-8 at byte 12")
        self.assert_refused(b"[", "invalid JSON")
        self.assert_refused(b"{}", "not a JSON array")
        self.assert_refused(timing_json({(1, 1): [[0, 1, 0, 9]]}).replace(b"9]]", b"NaN]]"), "NaN")
        self.assert_refused(timing_json({(1, 1): [[0, 1, 0, 9.5]]}), "fraction")
        self.assert_refused(b'[{"surah": 1, "surah": 1}]', "repeats a field name")

    def test_the_entries(self):
        self.assert_refused(timing_json(drop=[(2, 1)]), "has 7 ayat, not 8")
        self.assert_refused(timing_json(drop=[(2, 1)], extra=[_entry(2, 4)]), "lacks 2:1")
        self.assert_refused(timing_json(extra=[_entry(1, 1)]), "repeats 1:1")
        self.assert_refused(timing_json(extra=[_entry(4, 1)]), "surah 4 of 3")
        self.assert_refused(timing_json(drop=[(3, 1)], extra=[_entry(1, 5)]), "no ayah of surah 3")
        self.assert_refused(
            timing_json(drop=[(2, 3)], extra=[_entry(1, 5)]),
            "surah 1 has 5 ayat in the file, 4 in the metadata",
            self.metadata,
        )
        self.assert_refused(b"[1]", "entry 1 is not an object")
        self.assert_refused(b'[{"surah": 1, "ayah": 1, "segments": []}]', "exactly the fields")
        self.assert_refused(b'[{"surah": 1, "ayah": 1}]', "exactly the fields")
        self.assert_refused(json.dumps([dict(_entry(1, 1), timing=[])]).encode(), "exactly the fields")
        no_segments = _entry(1, 1)
        del no_segments["segments"]
        self.assert_refused(json.dumps([dict(no_segments, timing=[])]).encode(), "exactly the fields")
        self.assert_refused(b'[{"surah": true, "ayah": 1, "segments": [], "stats": {}}]', "surah is not an integer")
        self.assert_refused(b'[{"surah": 1, "ayah": 0, "segments": [], "stats": {}}]', "ayah is 0, below 1")
        short_stats = b'[{"surah": 1, "ayah": 1, "segments": [], "stats": {"insertions": 0}}]'
        self.assert_refused(short_stats, "stats does not have")
        stats = b'{"insertions": 0, "deletions": -1, "transpositions": 0}'
        self.assert_refused(b'[{"surah": 1, "ayah": 1, "segments": [], "stats": %s}]' % stats, "stats.deletions is -1")
        for value in ({}, None, 0, "[]"):
            not_an_array = dict(_entry(1, 1), segments=value)
            self.assert_refused(json.dumps([not_an_array]).encode(), "segments is not an array")

    def test_the_segments(self):
        for segs, words in (
            ([[0, 1, 0]], "segment 1 is not an array of four integers"),
            ([[0, 1, 0, "9"]], "segment 1 is not an integer"),
            ([[0, 1, -1, 9]], "segment 1 is -1, below 0"),
            ([[1, 1, 0, 9]], "segment 1 covers words 1 to 1"),
            ([[2, 1, 9, 8]], "segment 1 covers words 2 to 1"),
            ([[0, 1, 0, 9, 9]], "segment 1 is not an array of four integers"),
            ([[0, 1, 0, 9], 7], "segment 2 is not an array of four integers"),
            ([[0, 1, 0, 9], [1, 2, 9.0, 9]], "fraction"),
            ([[0, 2, 0, 500], [1, 3, 500, 900]], "segment 2 starts at word 1, before the previous segment's end word"),
            ([[0, 2, 0, 500], [1, 3, 400, 900]], "segment 2 starts at word 1, before the previous segment's end word"),
            ([[0, 2, 9, 8], [1, 3, 9, 9]], "segment 2 starts at word 1, before the previous segment's end word"),
        ):
            with self.subTest(words):
                self.assert_refused(timing_json({(2, 2): segs}), words if words == "fraction" else "(2:2) " + words)


def _stats():
    return {"insertions": 0, "deletions": 0, "transpositions": 0}


def _entry(surah, ayah):
    return {"surah": surah, "ayah": ayah, "segments": [], "stats": _stats()}


class WordsTest(unittest.TestCase):
    def setUp(self):
        self.text = read_tanzil_text(synthetic.synthetic_text_xml())

    def test_with_the_text(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        timings = read_timing(timing_json(default=two_words), SYNTHETIC)
        result = drift.words(timings, self.text)
        # 26 tokens in the 8 synthetic ayat, two covered in each.
        self.assertEqual(result["uncovered_words"], 10)
        self.assertEqual(result["word_count_from"], "tanzil")
        self.assertEqual(result["word_index_problems"], [])
        self.assertEqual(
            result["pause_mark_tokens"],
            {
                "U+06D6": {"tokens": 1, "covered": 1},
                "U+06D7": {"tokens": 1, "covered": 0},
                "U+06DA": {"tokens": 1, "covered": 1},
            },
        )

    def test_an_index_past_the_tokens(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        timings = read_timing(timing_json({(1, 4): [[0, 1, 0, 100], [1, 3, 100, 200]]}, default=two_words), SYNTHETIC)
        problems = drift.words(timings, self.text)["word_index_problems"]
        self.assertEqual(problems, [{"address": "hafs:1:4", "highest_word_end": 3, "tokens": 2}])

    def test_the_words_of_a_defective_segment_are_not_covered(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        for second in ([1, 2, 100, 100], [1, 2, 90, 200], [1, 2, 300, 200]):
            with self.subTest(second=second):
                timings = read_timing(timing_json({(1, 1): [[0, 1, 0, 100], second]}, default=two_words), SYNTHETIC)
                self.assertEqual(drift.words(timings, self.text)["uncovered_words"], 11)
                self.assertEqual(drift.words(timings)["uncovered_words"], 1)

    def test_an_ayah_without_timing_has_no_word_covered(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        for missing in (ABSENT, []):
            timings = read_timing(timing_json({(1, 1): missing}, default=two_words), SYNTHETIC)
            # 1:1 has four tokens in the synthetic text.
            self.assertEqual(drift.words(timings, self.text)["uncovered_words"], 12)

    def test_without_the_text(self):
        timings = read_timing(timing_json({(1, 1): [[1, 2, 0, 100], [4, 5, 100, 200]]}), SYNTHETIC)
        result = drift.words(timings)
        self.assertEqual(
            result,
            {"word_count_from": "timing", "uncovered_words": 3, "word_index_problems": None, "pause_mark_tokens": None},
        )


class TimingDefectsTest(unittest.TestCase):
    def test_each_listing_names_the_end_of_the_segment_just_before(self):
        segs = [[0, 1, 0, 500], [1, 2, 450, 400], [2, 3, 380, 380], [3, 4, 600, 700]]
        timings = read_timing(timing_json({(1, 2): segs}), SYNTHETIC)
        listed = drift.timing_defects(timings, {(1, 2): "001002.mp3"}, {})["defective_segments"]
        self.assertEqual(
            [(d["segment"], d["kinds"], d["previous_end_ms"]) for d in listed],
            [(2, ["end_before_start", "overlap"], 500), (3, ["overlap", "zero_length"], 400)],
        )

    def test_the_first_segment_has_no_previous_end(self):
        timings = read_timing(timing_json({(1, 2): [[0, 1, 9, 8]]}), SYNTHETIC)
        listed = drift.timing_defects(timings, {}, {})["defective_segments"]
        self.assertEqual(listed, [{"address": "hafs:1:2", "segment": 1, "kinds": ["end_before_start"],
                                   "start_ms": 9, "end_ms": 8, "previous_end_ms": None, "in_sample": False}])

    def test_a_sound_segment_before_an_earlier_end_is_counted_not_excluded(self):
        # Segment 3 is no overlap of segment 2, which ends before it starts, but starts before segment 1 ends.
        # Segment 4 starts after segment 3 ends but still before segment 1 ends.
        segs = [[0, 1, 0, 9000], [1, 2, 9500, 100], [2, 3, 500, 990], [3, 4, 1000, 1100], [4, 5, 9100, 9200]]
        timings = read_timing(timing_json({(1, 2): segs}), SYNTHETIC)
        self.assertEqual([s.defects for s in timings[(1, 2)].segments], [(), ("end_before_start",), (), (), ()])
        counts = drift.timing_defects(timings, {(1, 2): "001002.mp3"}, {})
        self.assertEqual(counts["whole"]["sound_segments_before_an_earlier_end"], 2)
        self.assertEqual(counts["sample"]["sound_segments_before_an_earlier_end"], 2)
        self.assertEqual((counts["whole"]["defective_segments"], counts["whole"]["overlap"]), (1, 0))

    def test_no_segment_no_rate(self):
        timings = read_timing(timing_json(default=[]), SYNTHETIC)
        counts = drift.timing_defects(timings, {}, {})
        self.assertEqual((counts["whole"]["segments"], counts["whole"]["defects_per_10000_segments"]), (0, None))
        self.assertEqual((counts["sample"]["ayat"], counts["sample"]["defects_per_10000_segments"]), (0, None))


class RunCase(BuildCase):
    def setUp(self):
        super().setUp()
        self.folder = self.work / EDITION
        self.folder.mkdir()
        self.timing = self.work / "timing.json"

    def add(self, name, levels):
        (self.folder / name).write_bytes(f.stream(levels))

    def run_drift(self, overrides=None, text=False, edition=EDITION, folder=None):
        self.timing.write_bytes(timing_json(overrides))
        paths = {}
        if text:
            synthetic.write_synthetic_source(self.source)
            paths = {
                "text_path": self.source / synthetic.TEXT_FILE,
                "metadata_path": self.source / synthetic.METADATA_FILE,
            }
        return drift.run_drift(self.timing, folder or self.folder, edition, SYNTHETIC, **paths)


class RunTest(RunCase):
    def test_a_pass(self):
        self.add("001001.mp3", TWO_RUNS)
        self.add("002003.mp3", THREE_RUNS)
        (self.folder / "notes.txt").write_bytes(b"ignored")
        report = self.run_drift({(1, 1): segments(shift=20), (2, 3): three_segments(7)})
        files = report["files"]
        self.assertEqual([x["file"] for x in files], ["001001.mp3", "002003.mp3"])
        self.assertEqual([x["address"] for x in files], ["hafs:1:1", "hafs:2:3"])
        summary = report["summary"]
        self.assertEqual((summary["files_measured"], summary["entries_without_file"]), (2, 6))
        self.assertEqual(summary["pause_samples"], 3)
        self.assertEqual((summary["median_offset_ms"], summary["max_abs_offset_ms"]), (7.0, 20.0))
        self.assertEqual(summary["onset_median_ms"], 10.0)
        self.assertEqual(summary["verdict"], "PASS")
        self.assertEqual(report["edition"], EDITION)
        self.assertRegex(report["inputs"]["timing_sha256"], "^[0-9a-f]{64}$")
        self.assertRegex(files[0]["sha256"], "^[0-9a-f]{64}$")

    def test_an_ayah_without_timing_is_listed_and_its_file_not_measured(self):
        self.add("001001.mp3", TWO_RUNS)
        self.add("001002.mp3", TWO_RUNS)
        self.add("001003.mp3", THREE_RUNS)
        report = self.run_drift({(1, 1): [[0, 1, 900, 100]], (1, 2): ABSENT, (1, 3): [], (2, 1): ABSENT})
        two_runs = digest.sha256_bytes(f.stream(TWO_RUNS))
        three_runs = digest.sha256_bytes(f.stream(THREE_RUNS))
        self.assertEqual([x["file"] for x in report["files"]], ["001001.mp3"])
        summary = report["summary"]
        counts = (summary["files_measured"], summary["files_without_timing"], summary["entries_without_file"])
        self.assertEqual(counts, (1, 2, 5))
        self.assertEqual(
            report["timing"]["ayat_without_timing"],
            [
                {"address": "hafs:1:2", "segments": "absent", "file": "001002.mp3", "sha256": two_runs},
                {"address": "hafs:1:3", "segments": "empty", "file": "001003.mp3", "sha256": three_runs},
                {"address": "hafs:2:1", "segments": "absent", "file": None, "sha256": None},
            ],
        )
        whole = report["timing"]["whole"]
        self.assertEqual(
            (whole["ayat"], whole["ayat_without_timing"], whole["no_segments_field"], whole["empty_segments"]),
            (8, 3, 2, 1),
        )
        sample = report["timing"]["sample"]
        self.assertEqual(
            (sample["ayat"], sample["ayat_without_timing"], sample["no_segments_field"], sample["empty_segments"]),
            (3, 2, 1, 1),
        )
        output = drift.lines(report)
        self.assertIn(
            "ayah without timing hafs:1:2: segments absent, file 001002.mp3 sha256 %s not measured" % two_runs, output
        )
        self.assertIn(
            "ayah without timing hafs:1:3: segments empty, file 001003.mp3 sha256 %s not measured" % three_runs, output
        )
        self.assertIn("ayah without timing hafs:2:1: segments absent, no file", output)
        summary_line = (
            "files measured 1, files without timing 2, entries without a file 5, end-check failures 0, "
            "end checks not made 1"
        )
        self.assertIn(summary_line, output)

    def test_defects_are_counted_listed_and_leave_the_verdict(self):
        self.add("001001.mp3", TWO_RUNS)
        self.add("002003.mp3", THREE_RUNS)
        sound = {(1, 1): segments(shift=20), (2, 3): three_segments(7)}
        passed = self.run_drift(sound)
        overrides = dict(sound)
        # In the sample: a zero-length segment and one that ends before it starts, at the end of each file.
        overrides[(1, 1)] = segments(shift=20) + [[2, 3, 1600, 1600]]
        overrides[(2, 3)] = three_segments(7) + [[3, 4, 99000, 98000]]
        # Outside it: an overlap that also ends before it starts, and a plain overlap.
        overrides[(1, 4)] = [[0, 1, 180, 720], [1, 2, 700, 650], [2, 3, 900, 1440]]
        overrides[(3, 1)] = [[0, 1, 180, 720], [1, 2, 710, 1440]]
        report = self.run_drift(overrides)
        self.assertEqual(report["summary"], passed["summary"])
        self.assertEqual(report["summary"]["verdict"], "PASS")
        self.assertEqual([x["defective_segments"] for x in report["files"]], [1, 1])
        self.assertEqual([x["timing_end_ms"] for x in report["files"]], [1460, 10440])
        t = report["timing"]
        self.assertEqual(
            t["whole"],
            {
                "ayat": 8, "ayat_without_timing": 0, "no_segments_field": 0, "empty_segments": 0, "segments": 20,
                "defective_segments": 4, "end_before_start": 2, "overlap": 2, "zero_length": 1,
                "sound_segments_before_an_earlier_end": 0, "defects_per_10000_segments": 2000.0,
            },
        )
        self.assertEqual(
            t["sample"],
            {
                "ayat": 2, "ayat_without_timing": 0, "no_segments_field": 0, "empty_segments": 0, "segments": 7,
                "defective_segments": 2, "end_before_start": 1, "overlap": 0, "zero_length": 1,
                "sound_segments_before_an_earlier_end": 0, "defects_per_10000_segments": 10000.0 * 2 / 7,
            },
        )
        self.assertEqual(
            t["defective_segments"],
            [
                {"address": "hafs:1:1", "segment": 3, "kinds": ["zero_length"], "start_ms": 1600, "end_ms": 1600,
                 "previous_end_ms": 1460, "in_sample": True},
                {"address": "hafs:1:4", "segment": 2, "kinds": ["end_before_start", "overlap"], "start_ms": 700,
                 "end_ms": 650, "previous_end_ms": 720, "in_sample": False},
                {"address": "hafs:2:3", "segment": 4, "kinds": ["end_before_start"], "start_ms": 99000,
                 "end_ms": 98000, "previous_end_ms": 10440, "in_sample": True},
                {"address": "hafs:3:1", "segment": 2, "kinds": ["overlap"], "start_ms": 710, "end_ms": 1440,
                 "previous_end_ms": 720, "in_sample": False},
            ],
        )
        output = drift.lines(report)
        self.assertIn(
            "whole timing file: ayat 8, without timing 0 (no segments field 0, empty 0), segments 20, defective 4 "
            "(end before start 2, overlap 2, zero length 1), segments not defective that start before an earlier "
            "one ends 0",
            output,
        )
        self.assertIn(
            "sample: ayat 2, without timing 0 (no segments field 0, empty 0), segments 7, defective 2 "
            "(end before start 1, overlap 0, zero length 1), segments not defective that start before an earlier "
            "one ends 0",
            output,
        )
        self.assertIn(
            "defective segments per 10,000 segments (not a criterion): whole timing file 2000.0, sample 2857.1", output
        )
        self.assertIn(
            "defective segment hafs:1:1 segment 3 (zero_length): start 1600 ms, end 1600 ms, previous end 1460 ms, "
            "in the sample",
            output,
        )
        self.assertIn(
            "defective segment hafs:1:4 segment 2 (end_before_start, overlap): start 700 ms, end 650 ms, "
            "previous end 720 ms",
            output,
        )
        self.assertIn("verdict PASS", output)

    def test_a_drifting_rate_fails_the_slope(self):
        self.add("002003.mp3", THREE_RUNS)
        report = self.run_drift({(2, 3): three_segments(9)})
        self.assertAlmostEqual(report["summary"]["slope_ms_per_minute"], 60.0)
        self.assertEqual([m.split(":")[0] for m in report["summary"]["missed"]], ["slope"])
        report = self.run_drift({(2, 3): three_segments(-9)})
        self.assertAlmostEqual(report["summary"]["slope_ms_per_minute"], -60.0)
        self.assertEqual(report["summary"]["verdict"], "FAIL")

    def test_timing_past_the_audio_fails_the_end_check(self):
        self.add("001001.mp3", TWO_RUNS)
        self.add("001002.mp3", TWO_RUNS)
        report = self.run_drift({(1, 2): segments(end_shift=int(TWO_RUNS_MS) + 37 - 1440)})
        self.assertEqual([x["end_check"] for x in report["files"]], ["pass", "fail"])
        self.assertEqual(
            report["summary"]["missed"],
            [
                "end check: 1 files end more than one frame after the audio",
                "slope: no file has two pause samples at distinct times",
            ],
        )

    def test_a_constant_offset_fails_the_median(self):
        self.add("001001.mp3", TWO_RUNS)
        self.add("001002.mp3", THREE_RUNS)
        three = [[0, 1, 281, 821], [1, 2, 1001, 9821], [2, 3, 10001, 10440]]
        report = self.run_drift({(1, 1): segments(shift=101), (1, 2): three})
        self.assertEqual(report["summary"]["median_offset_ms"], 101.0)
        self.assertEqual([m.split(":")[0] for m in report["summary"]["missed"]], ["median offset"])

    def test_the_word_check_through_the_tanzil_reader(self):
        self.add("001001.mp3", TWO_RUNS)
        report = self.run_drift({(1, 4): [[0, 1, 0, 100], [1, 3, 100, 200]]}, text=True)
        self.assertEqual(report["words"]["word_count_from"], "tanzil")
        problems = report["words"]["word_index_problems"]
        self.assertEqual(problems, [{"address": "hafs:1:4", "highest_word_end": 3, "tokens": 2}])
        self.assertRegex(report["inputs"]["text_sha256"], "^[0-9a-f]{64}$")
        self.assertRegex(report["inputs"]["metadata_sha256"], "^[0-9a-f]{64}$")

    def test_no_text_reaches_the_report_or_the_output(self):
        self.add("001002.mp3", TWO_RUNS)
        report = self.run_drift(text=True)
        data = drift.encode_report(report)
        self.assertEqual(data, drift.encode_report(self.run_drift(text=True)))
        self.assert_safe_message(data.decode("ascii"))
        self.assert_safe_message("\n".join(drift.lines(report)))
        self.assertNotIn(b"\\u", data)
        for name in json.loads(data)["words"]["pause_mark_tokens"]:
            self.assertRegex(name, r"^U\+06D[6-9AB]( U\+06D[6-9AB])*$")

    def test_the_report_rounds_to_a_tenth_of_a_millisecond(self):
        data = drift.encode_report({"a": 1 / 3.0, "b": -0.04, "c": [2.26, 7]})
        self.assertEqual(json.loads(data), {"a": 0.3, "b": 0.0, "c": [2.3, 7]})
        self.assertNotIn(b"-0.0", data)

    def test_refusals(self):
        self.add("001001.mp3", TWO_RUNS)
        for kwargs, words in (
            ({"edition": "Other_Edition"}, "not named Other_Edition"),
            ({"edition": "Test Edition"}, "a character other than"),
        ):
            with self.assertRaises(PackError) as caught:
                self.run_drift(**kwargs)
            self.assertIn(words, str(caught.exception))
        self.add("004001.mp3", TWO_RUNS)
        with self.assertRaises(PackError) as caught:
            self.run_drift()
        self.assertIn("004001.mp3 names 4:1, which the timing file does not have", str(caught.exception))
        (self.folder / "004001.mp3").unlink()
        (self.folder / "001003.mp3").write_bytes(f.stream(TWO_RUNS)[:-1])
        with self.assertRaises(PackError) as caught:
            self.run_drift()
        self.assertIn("001003.mp3: the frame at byte %d is truncated" % (288 * 41), str(caught.exception))
        empty = self.work / "empty" / EDITION
        empty.mkdir(parents=True)
        with self.assertRaises(PackError) as caught:
            self.run_drift(folder=empty)
        self.assertIn("holds no SSSAAA.mp3 file", str(caught.exception))


class DriftCliTest(CliCase):
    def setUp(self):
        super().setUp()
        self.folder = self.work / EDITION
        self.folder.mkdir()
        (self.folder / "002003.mp3").write_bytes(f.stream(THREE_RUNS))
        synthetic.write_synthetic_source(self.source)
        self.timing = self.work / "timing.json"
        self.report = self.work / "report.json"

    def drift(self, later=0, report=None, *more):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        self.timing.write_bytes(timing_json({(2, 3): three_segments(later)}, default=two_words))
        argv = ["drift", "--timing", self.timing, "--audio", self.folder, "--edition", EDITION]
        argv += ["--text", self.source / synthetic.TEXT_FILE, "--metadata", self.source / synthetic.METADATA_FILE]
        argv += ["--report", report or self.report] + list(more)
        with hafs_shaped_profiles():
            return self.run_cli(*argv)

    def test_a_pass_writes_the_report(self):
        code, out, err = self.drift()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("edition %s" % EDITION, out)
        self.assertIn("002003.mp3 hafs:2:3 sha256 ", out)
        marks = "U+06D6 tokens 1 covered 1; U+06D7 tokens 1 covered 0; U+06DA tokens 1 covered 1"
        self.assertIn("pause-mark-only tokens: " + marks, out)
        self.assertIn("verdict PASS", out)
        self.assertIn("report %s" % self.report, out)
        self.assertEqual(json.loads(self.report.read_bytes())["summary"]["verdict"], "PASS")

    def test_defects_and_an_ayah_without_timing_still_exit_0_on_a_pass(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        overrides = {(2, 3): three_segments(0), (1, 2): [[0, 1, 500, 400], [1, 2, 500, 600]], (1, 1): ABSENT}
        self.timing.write_bytes(timing_json(overrides, default=two_words))
        with hafs_shaped_profiles():
            code, out, err = self.run_cli(
                "drift", "--timing", self.timing, "--audio", self.folder, "--edition", EDITION,
                "--text", self.source / synthetic.TEXT_FILE, "--metadata", self.source / synthetic.METADATA_FILE,
            )
        self.assertEqual((code, err), (0, ""))
        self.assertIn("002003.mp3 hafs:2:3 sha256 ", out)
        self.assertIn("segments 3 (defective 0), timing end 10440 ms, end check pass", out)
        rate = "defective segments per 10,000 segments (not a criterion): whole timing file 666.7, sample 0.0"
        self.assertIn(rate, out)
        self.assertIn("defective segment hafs:1:2 segment 1 (end_before_start): start 500 ms, end 400 ms", out)
        self.assertIn("ayah without timing hafs:1:1: segments absent, no file", out)
        self.assertIn("verdict PASS", out)

    def test_a_fail_exits_65(self):
        code, out, _ = self.drift(later=9)
        self.assertEqual(code, 65)
        self.assertIn("verdict FAIL: slope: |60.0| ms per minute is above 50", out)

    def test_a_report_inside_a_git_tree_is_refused(self):
        tree = self.work / "tree"
        (tree / ".git").mkdir(parents=True)
        for report in (tree / "sub" / "report.json", REPO / "drift-report.json"):
            code, _, err = self.drift(0, report)
            self.assertEqual(code, 65)
            self.assertIn("inside the Git working tree", err)
            self.assertFalse(report.exists())

    def test_a_word_index_past_the_text_exits_65_on_a_pass(self):
        two_words = [[0, 1, 0, 100], [1, 2, 100, 200]]
        overrides = {(2, 3): three_segments(0), (1, 4): [[0, 1, 0, 100], [1, 3, 100, 200]]}
        self.timing.write_bytes(timing_json(overrides, default=two_words))
        with hafs_shaped_profiles():
            code, out, _ = self.run_cli(
                "drift", "--timing", self.timing, "--audio", self.folder, "--edition", EDITION,
                "--text", self.source / synthetic.TEXT_FILE, "--metadata", self.source / synthetic.METADATA_FILE,
            )
        self.assertEqual(code, 65)
        self.assertIn("word index problems 1: hafs:1:4 ends at word 3 of 2 tokens", out)
        self.assertIn("verdict PASS", out)

    def test_a_report_that_is_a_folder_is_refused(self):
        folder = self.work / "reports"
        folder.mkdir()
        code, _, err = self.drift(0, folder)
        self.assertEqual(code, 65)
        self.assertIn("is a folder", err)

    def test_text_without_metadata_is_a_usage_error(self):
        with hafs_shaped_profiles():
            code, _, err = self.run_cli(
                "drift", "--timing", self.timing, "--audio", self.folder, "--edition", EDITION,
                "--text", self.work / "t.xml",
            )
        self.assertEqual(code, 64)
        self.assertIn("--text and --metadata go together", err)


if __name__ == "__main__":
    unittest.main()
