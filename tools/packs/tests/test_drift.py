"""The recitation drift tool, on synthetic MP3 bytes, synthetic timing and the synthetic Tanzil source."""

import json
import unittest
from pathlib import Path

import synthetic_source as synthetic
from hqpack import drift
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


def timing_json(overrides=None, default=None, drop=(), extra=()):
    overrides = overrides or {}
    entries = []
    for address in reversed(AYAT):
        if address in drop:
            continue
        entries.append(
            {
                "surah": address[0],
                "ayah": address[1],
                "segments": overrides.get(address, segments() if default is None else default),
                "stats": {"insertions": 0, "deletions": 1, "transpositions": 0},
            }
        )
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

    def test_an_entry_without_segments(self):
        result = drift.measure_file("001001.mp3", (1, 1), audio(TWO_RUNS), Timing(1, 1, ()))
        self.assertEqual((result["end_check"], result["onset_ms"], result["samples"]), ("pass", None, []))


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
        ]
        summary = drift.summarise(files, 8)
        counts = (summary["files_measured"], summary["entries_without_file"], summary["end_check_failures"])
        self.assertEqual(counts, (3, 5, 1))
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
        data = timing_json({(1, 1): [], (1, 2): [[0, 1, 0, 500], [1, 3, 500, 500], [5, 6, 500, 900]]})
        timings = read_timing(data, SYNTHETIC)
        self.assertEqual(timings[(1, 1)].segments, ())
        self.assertEqual(len(timings[(1, 2)].segments), 3)

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
        self.assert_refused(b'[{"surah": true, "ayah": 1, "segments": [], "stats": {}}]', "surah is not an integer")
        self.assert_refused(b'[{"surah": 1, "ayah": 0, "segments": [], "stats": {}}]', "ayah is 0, below 1")
        short_stats = b'[{"surah": 1, "ayah": 1, "segments": [], "stats": {"insertions": 0}}]'
        self.assert_refused(short_stats, "stats does not have")
        stats = b'{"insertions": 0, "deletions": -1, "transpositions": 0}'
        self.assert_refused(b'[{"surah": 1, "ayah": 1, "segments": [], "stats": %s}]' % stats, "stats.deletions is -1")
        not_an_array = dict(_entry(1, 1), segments={})
        self.assert_refused(json.dumps([not_an_array]).encode(), "segments is not an array")

    def test_the_segments(self):
        for segs, words in (
            ([[0, 1, 0]], "segment 1 is not an array of four integers"),
            ([[0, 1, 0, "9"]], "segment 1 is not an integer"),
            ([[0, 1, -1, 9]], "segment 1 is -1, below 0"),
            ([[1, 1, 0, 9]], "segment 1 covers words 1 to 1"),
            ([[0, 1, 9, 8]], "segment 1 ends at 8 ms, before its start at 9 ms"),
            ([[0, 1, 0, 500], [1, 2, 499, 900]], "segment 2 starts at 499 ms, before the previous segment ends at 500"),
            ([[0, 2, 0, 500], [1, 3, 500, 900]], "segment 2 starts at word 1, before the previous segment's end word"),
        ):
            with self.subTest(words):
                self.assert_refused(timing_json({(2, 2): segs}), "(2:2) " + words)


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

    def test_without_the_text(self):
        timings = read_timing(timing_json({(1, 1): [[1, 2, 0, 100], [4, 5, 100, 200]]}), SYNTHETIC)
        result = drift.words(timings)
        self.assertEqual(
            result,
            {"word_count_from": "timing", "uncovered_words": 3, "word_index_problems": None, "pause_mark_tokens": None},
        )


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
