"""Drift between quran-align word timing and the per-ayah MP3 files served today (B0.5, D-167 (2), D-179).

Per file `SSSAAA.mp3` of the folder, with the timing entry of that ayah:

- end check: the last segment must not end more than one frame after the
  playable audio;
- onset: the first segment's start minus the audio's speech onset;
- pause alignment: for every silence of at least MIN_PAUSE_MS between two
  speech runs, the midpoint of the nearest boundary between consecutive
  segments (the gap, or the join) minus the silence's midpoint; positive when
  the timing is later than the audio;
- trend: the least-squares slope of those offsets against their time in the
  file, in ms per minute, with one intercept per file.

A defective segment (quran_align.py) is kept out of every measure (D-179): the
end check and the onset use the last and first segment that is not defective,
a boundary with a defective segment on either side gives no offset, and its
words count as not covered. An ayah without timing has no file measured; it is
listed. The defects are counted by kind over the whole timing file and over
the sample (the ayat whose file is in the folder) and listed with their times;
they do not change the verdict. Since an overlap is judged against the
segment just before, a segment that is not defective can still start before
the end of an earlier one across a defective segment; those are counted, not
excluded.

Speech is read from the Layer III side information (mp3.py), never from
decoded samples. A granule's level is the highest `global_gain` among its
channels that carry main data (`part2_3_length` above 0), and 0 when none
does. The file's loud level is the LOUD_PERCENTILE of its granule levels
(nearest rank); a granule is speech when its level is above 0 and above the
loud level minus SILENCE_DROP_STEPS (1.5 dB a step). A speech run is a run of
speech granules lasting at least SPEECH_RUN_MS; shorter runs count as silence.
The onset is the start of the first speech run.

Nothing here holds or prints text: the report holds the edition, file names,
addresses, SHA-256 and numbers.
"""

from __future__ import annotations

import json
import math
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from . import digest, mp3
from .errors import PackError, code_point
from .git_tree import git_tree
from .options import PAUSE_MARKS
from .quran_align import read_timing
from .source_checks import check_structure
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .tokens import token_spans

REPORT_FORMAT = "holyquran-recitation-drift"
REPORT_VERSION = 1

# D-179, the lead's thresholds for the word-timing label (D-167 (2)).
MAX_MEDIAN_OFFSET_MS = 100
MAX_P95_OFFSET_MS = 250
MAX_SLOPE_MS_PER_MINUTE = 50
MIN_PAUSE_MS = 120

# D-179, how speech is told from silence.
LOUD_PERCENTILE = 90
SILENCE_DROP_STEPS = 20
SPEECH_RUN_MS = 50

_AUDIO_NAME = re.compile(r"([0-9]{3})([0-9]{3})\.mp3\Z")
_EDITION = re.compile(r"[A-Za-z0-9_]+\Z")
_PAUSE = frozenset(chr(cp) for cp in PAUSE_MARKS)


@dataclass(frozen=True)
class Speech:
    onset_ms: Optional[float]
    pauses: tuple


def granule_level(channels) -> int:
    return max((gain for bits, gain in channels if bits > 0), default=0)


def speech(audio) -> Speech:
    """The speech onset and the pauses (start_ms, end_ms) between speech runs of `audio`."""
    levels = [granule_level(g.channels) for g in audio.granules]
    loud = _nearest_rank(sorted(levels), LOUD_PERCENTILE)
    threshold = max(loud - SILENCE_DROP_STEPS, 0)
    runs = []
    start = None
    for index, level in enumerate(levels + [0]):
        if level > threshold:
            if start is None:
                start = index
        elif start is not None:
            if (index - start) * audio.granule_ms >= SPEECH_RUN_MS:
                runs.append((start, index))
            start = None
    if not runs:
        return Speech(onset_ms=None, pauses=())
    origin = audio.granules[0].start_ms

    def at(index):
        return origin + index * audio.granule_ms

    pauses = tuple(
        (at(a_end), at(b_start))
        for (_, a_end), (b_start, _) in zip(runs, runs[1:])
        if (b_start - a_end) * audio.granule_ms >= MIN_PAUSE_MS
    )
    return Speech(onset_ms=at(runs[0][0]), pauses=pauses)


def pause_offsets(pauses, segments) -> list:
    """(pause midpoint, offset) per pause: the nearest segment boundary's midpoint minus the pause's."""
    boundaries = [
        (a.end_ms + b.start_ms) / 2.0 for a, b in zip(segments, segments[1:]) if not a.defects and not b.defects
    ]
    result = []
    for start, end in pauses:
        middle = (start + end) / 2.0
        if boundaries:
            nearest = min(boundaries, key=lambda b: abs(b - middle))
            result.append((middle, nearest - middle))
    return result


def slope_ms_per_minute(files) -> Optional[float]:
    """Least-squares slope of offset against time in the file (ms per minute), with one intercept per file.

    `files` holds one list of (time, offset) per file. Centring each file on its
    own means keeps a constant offset that differs between files from reading
    as a rate. None when no file has two samples at distinct times.
    """
    sxx = sxy = 0.0
    for samples in files:
        if not samples:
            continue
        xs = [t / 60000.0 for t, _ in samples]
        ys = [o for _, o in samples]
        mx = sum(xs) / len(xs)
        my = sum(ys) / len(ys)
        sxx += sum((x - mx) ** 2 for x in xs)
        sxy += sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    if sxx == 0:
        return None
    return sxy / sxx


def measure_file(name, address, audio, timing) -> dict:
    segments = timing.segments
    sound = timing.sound()
    found = speech(audio)
    result = {
        "file": name,
        "address": "hafs:%d:%d" % address,
        "sample_rate": audio.sample_rate,
        "channel_mode": audio.channel_mode,
        "frames": audio.frames,
        "frame_ms": audio.frame_ms,
        "duration_ms": audio.duration_ms,
        "delay_known": audio.delay_known,
        "lame_tag": audio.lame_tag,
        "encoder_delay": audio.encoder_delay,
        "padding": audio.padding,
        "segments": len(segments),
        "defective_segments": len(segments) - len(sound),
        "timing_end_ms": sound[-1].end_ms if sound else None,
        "end_check": "pass" if sound else "not made",
        "speech_onset_ms": found.onset_ms,
        "onset_ms": None,
        "pauses": len(found.pauses),
        "samples": [],
    }
    if sound and sound[-1].end_ms > audio.duration_ms + audio.frame_ms:
        result["end_check"] = "fail"
    if sound and found.onset_ms is not None:
        result["onset_ms"] = sound[0].start_ms - found.onset_ms
    result["samples"] = [{"at_ms": t, "offset_ms": o} for t, o in pause_offsets(found.pauses, segments)]
    return result


def verdict(summary) -> list:
    """The criteria of D-179 that `summary` misses; empty for PASS."""
    missed = []
    if summary["end_check_failures"]:
        missed.append("end check: %d files end more than one frame after the audio" % summary["end_check_failures"])
    median = summary["median_offset_ms"]
    if median is None:
        missed.append("median offset: no pause sample")
    elif abs(median) > MAX_MEDIAN_OFFSET_MS:
        missed.append("median offset: |%.1f| ms is above %d ms" % (median, MAX_MEDIAN_OFFSET_MS))
    p95 = summary["p95_abs_offset_ms"]
    if p95 is None:
        missed.append("p95 |offset|: no pause sample")
    elif p95 > MAX_P95_OFFSET_MS:
        missed.append("p95 |offset|: %.1f ms is above %d ms" % (p95, MAX_P95_OFFSET_MS))
    slope = summary["slope_ms_per_minute"]
    if slope is None:
        missed.append("slope: no file has two pause samples at distinct times")
    elif abs(slope) > MAX_SLOPE_MS_PER_MINUTE:
        missed.append("slope: |%.1f| ms per minute is above %d" % (slope, MAX_SLOPE_MS_PER_MINUTE))
    return missed


def summarise(files, entries, files_without_timing) -> dict:
    samples = [(s["at_ms"], s["offset_ms"]) for f in files for s in f["samples"]]
    offsets = [o for _, o in samples]
    magnitudes = sorted(abs(o) for o in offsets)
    onsets = sorted(f["onset_ms"] for f in files if f["onset_ms"] is not None)
    summary = {
        "files_measured": len(files),
        "files_without_timing": files_without_timing,
        "entries_without_file": entries - len(files) - files_without_timing,
        "end_check_failures": sum(1 for f in files if f["end_check"] == "fail"),
        "end_checks_not_made": sum(1 for f in files if f["end_check"] == "not made"),
        "onset_median_ms": _median(onsets),
        "onset_max_abs_ms": max((abs(o) for o in onsets), default=None),
        "pause_samples": len(samples),
        "median_offset_ms": _median(sorted(offsets)),
        "p95_abs_offset_ms": _nearest_rank(magnitudes, 95) if magnitudes else None,
        "max_abs_offset_ms": magnitudes[-1] if magnitudes else None,
        "slope_ms_per_minute": slope_ms_per_minute(
            [[(s["at_ms"], s["offset_ms"]) for s in f["samples"]] for f in files]
        ),
    }
    missed = verdict(summary)
    summary["verdict"] = "FAIL" if missed else "PASS"
    summary["missed"] = missed
    return summary


def words(timings, text=None) -> dict:
    """Words no segment covers, and with the text, the entries past its token count and the pause-mark-only tokens."""
    uncovered = 0
    problems = []
    marks = {}
    ayat = {}
    if text is not None:
        ayat = {(a.surah, a.number): a.text.value for sura in text.suras for a in sura.ayat}
    for address in sorted(timings):
        segments = timings[address].segments
        covered = set()
        for s in timings[address].sound():
            covered.update(range(s.word_start, s.word_end))
        highest = segments[-1].word_end if segments else 0
        if text is None:
            uncovered += highest - len(covered)
            continue
        tokens = token_spans(ayat[address])
        if highest > len(tokens):
            problems.append({"address": "hafs:%d:%d" % address, "highest_word_end": highest, "tokens": len(tokens)})
        uncovered += sum(1 for i in range(len(tokens)) if i not in covered)
        for index, (start, end, _) in enumerate(tokens):
            token = ayat[address][start:end]
            if all(c in _PAUSE for c in token):
                key = " ".join(code_point(c) for c in token)
                counts = marks.setdefault(key, {"tokens": 0, "covered": 0})
                counts["tokens"] += 1
                counts["covered"] += index in covered
    return {
        "word_count_from": "tanzil" if text is not None else "timing",
        "uncovered_words": uncovered,
        "word_index_problems": problems if text is not None else None,
        "pause_mark_tokens": {k: marks[k] for k in sorted(marks)} if text is not None else None,
    }


def defect_counts(timings) -> dict:
    """Ayat without timing and segments by defect kind over `timings`, with the defect rate per 10,000 segments."""
    counts = {
        "ayat": 0,
        "ayat_without_timing": 0,
        "no_segments_field": 0,
        "empty_segments": 0,
        "segments": 0,
        "defective_segments": 0,
        "end_before_start": 0,
        "overlap": 0,
        "zero_length": 0,
        "sound_segments_before_an_earlier_end": 0,
    }
    for timing in timings:
        counts["ayat"] += 1
        if not timing.segments:
            counts["ayat_without_timing"] += 1
            counts["empty_segments" if timing.segments_field else "no_segments_field"] += 1
        counts["segments"] += len(timing.segments)
        for segment in timing.segments:
            counts["defective_segments"] += bool(segment.defects)
            for kind in segment.defects:
                counts[kind] += 1
        latest = None
        for segment in timing.sound():
            if latest is not None and segment.start_ms < latest:
                counts["sound_segments_before_an_earlier_end"] += 1
            latest = segment.end_ms if latest is None else max(latest, segment.end_ms)
    counts["defects_per_10000_segments"] = (
        counts["defective_segments"] * 10000.0 / counts["segments"] if counts["segments"] else None
    )
    return counts


def timing_defects(timings, files, unmeasured) -> dict:
    """The counts over the whole file and over the sample, each defective segment and each ayah without timing.

    `files` maps the address of every audio file in the folder to its name, and
    `unmeasured` the address of each file left unmeasured to its SHA-256.
    """
    defective = []
    untimed = []
    for address in sorted(timings):
        timing = timings[address]
        where = "hafs:%d:%d" % address
        if not timing.segments:
            field = "empty" if timing.segments_field else "absent"
            untimed.append(
                {"address": where, "segments": field, "file": files.get(address), "sha256": unmeasured.get(address)}
            )
        previous = None
        for number, s in enumerate(timing.segments, 1):
            if s.defects:
                defective.append(
                    {
                        "address": where,
                        "segment": number,
                        "kinds": list(s.defects),
                        "start_ms": s.start_ms,
                        "end_ms": s.end_ms,
                        "previous_end_ms": previous,
                        "in_sample": address in files,
                    }
                )
            previous = s.end_ms
    return {
        "whole": defect_counts(timings[a] for a in sorted(timings)),
        "sample": defect_counts(timings[a] for a in sorted(files)),
        "defective_segments": defective,
        "ayat_without_timing": untimed,
    }


def check_report_path(path) -> None:
    tree = git_tree(path)
    if tree is not None:
        raise PackError(
            "the report %s is inside the Git working tree %s; it is written outside every repository" % (path, tree)
        )
    if Path(path).is_dir():
        raise PackError("the report %s is a folder" % path)


def run_drift(timing_path, audio_dir, edition, profile, text_path=None, metadata_path=None) -> dict:
    audio_dir = Path(audio_dir)
    if not _EDITION.match(edition):
        raise PackError("the edition name holds a character other than A-Z, a-z, 0-9 and _")
    folder = Path(os.path.abspath(str(audio_dir))).name
    if folder != edition:
        raise PackError(
            "the audio folder is not named %s; a timing file goes with its exact folder (D-167 (2))" % edition
        )
    inputs = {"timing_sha256": None, "text_sha256": None, "metadata_sha256": None}
    text = metadata = None
    if text_path is not None:
        text_bytes = Path(text_path).read_bytes()
        metadata_bytes = Path(metadata_path).read_bytes()
        inputs["text_sha256"] = digest.sha256_bytes(text_bytes)
        inputs["metadata_sha256"] = digest.sha256_bytes(metadata_bytes)
        text = read_tanzil_text(text_bytes)
        metadata = read_tanzil_metadata(metadata_bytes)
        check_structure(profile, text, metadata)
    timing_bytes = Path(timing_path).read_bytes()
    inputs["timing_sha256"] = digest.sha256_bytes(timing_bytes)
    timings = read_timing(timing_bytes, profile, metadata)
    files = []
    present = {}
    unmeasured = {}
    for name, address in _audio_files(audio_dir):
        if address not in timings:
            raise PackError("%s names %d:%d, which the timing file does not have" % ((name,) + address))
        present[address] = name
        data = (audio_dir / name).read_bytes()
        if not timings[address].segments:
            unmeasured[address] = digest.sha256_bytes(data)
            continue
        try:
            audio = mp3.read_mp3(data)
        except PackError as e:
            raise PackError("%s: %s" % (name, e)) from None
        measured = measure_file(name, address, audio, timings[address])
        measured["sha256"] = digest.sha256_bytes(data)
        files.append(measured)
    return {
        "format": REPORT_FORMAT,
        "version": REPORT_VERSION,
        "edition": edition,
        "inputs": inputs,
        "thresholds": {
            "max_median_offset_ms": MAX_MEDIAN_OFFSET_MS,
            "max_p95_offset_ms": MAX_P95_OFFSET_MS,
            "max_slope_ms_per_minute": MAX_SLOPE_MS_PER_MINUTE,
            "min_pause_ms": MIN_PAUSE_MS,
            "loud_percentile": LOUD_PERCENTILE,
            "silence_drop_steps": SILENCE_DROP_STEPS,
            "speech_run_ms": SPEECH_RUN_MS,
        },
        "files": files,
        "words": words(timings, text),
        "timing": timing_defects(timings, present, unmeasured),
        "summary": summarise(files, len(timings), len(present) - len(files)),
    }


def encode_report(report) -> bytes:
    return (json.dumps(_rounded(report), indent=2, ensure_ascii=True) + "\n").encode("ascii")


def lines(report) -> list:
    """The command's output: the edition, SHA-256, file names, addresses and numbers."""
    report = _rounded(report)
    result = ["edition %s" % report["edition"]]
    for key, value in report["inputs"].items():
        if value is not None:
            result.append("%s %s" % (key.replace("_", " "), value))
    for f in report["files"]:
        result.append(
            "%s %s sha256 %s: duration %s ms (delay %s, LAME tag %s), segments %d (defective %d), "
            "timing end %s ms, end check %s, onset %s ms, pauses %d, samples %d"
            % (
                f["file"], f["address"], f["sha256"], f["duration_ms"],
                "known" if f["delay_known"] else "not known", f["lame_tag"], f["segments"], f["defective_segments"],
                f["timing_end_ms"], f["end_check"], f["onset_ms"], f["pauses"], len(f["samples"]),
            )
        )
    s = report["summary"]
    w = report["words"]
    t = report["timing"]
    for name, counts in (("whole timing file", t["whole"]), ("sample", t["sample"])):
        result.append(
            "%s: ayat %d, without timing %d (no segments field %d, empty %d), segments %d, defective %d "
            "(end before start %d, overlap %d, zero length %d), segments not defective that start before "
            "an earlier one ends %d"
            % (
                name, counts["ayat"], counts["ayat_without_timing"], counts["no_segments_field"],
                counts["empty_segments"], counts["segments"], counts["defective_segments"],
                counts["end_before_start"], counts["overlap"], counts["zero_length"],
                counts["sound_segments_before_an_earlier_end"],
            )
        )
    result.append(
        "defective segments per 10,000 segments (not a criterion): whole timing file %s, sample %s"
        % (t["whole"]["defects_per_10000_segments"], t["sample"]["defects_per_10000_segments"])
    )
    for d in t["defective_segments"]:
        result.append(
            "defective segment %s segment %d (%s): start %d ms, end %d ms, previous end %s ms%s"
            % (d["address"], d["segment"], ", ".join(d["kinds"]), d["start_ms"], d["end_ms"], d["previous_end_ms"],
               ", in the sample" if d["in_sample"] else "")
        )
    for u in t["ayat_without_timing"]:
        result.append(
            "ayah without timing %s: segments %s, %s"
            % (
                u["address"], u["segments"],
                "file %s sha256 %s not measured" % (u["file"], u["sha256"]) if u["file"] else "no file",
            )
        )
    result.extend(
        [
            "files measured %d, files without timing %d, entries without a file %d, end-check failures %d, "
            "end checks not made %d"
            % (s["files_measured"], s["files_without_timing"], s["entries_without_file"], s["end_check_failures"],
               s["end_checks_not_made"]),
            "onset median %s ms, max |onset| %s ms" % (s["onset_median_ms"], s["onset_max_abs_ms"]),
            "pause samples %d, median offset %s ms, p95 |offset| %s ms, max |offset| %s ms, slope %s ms per minute"
            % (s["pause_samples"], s["median_offset_ms"], s["p95_abs_offset_ms"], s["max_abs_offset_ms"],
               s["slope_ms_per_minute"]),
            "words not covered by any segment %d (word count from %s)" % (w["uncovered_words"], w["word_count_from"]),
        ]
    )
    if w["pause_mark_tokens"] is not None:
        result.append(
            "pause-mark-only tokens: %s"
            % ("; ".join("%s tokens %d covered %d" % (k, v["tokens"], v["covered"])
                         for k, v in w["pause_mark_tokens"].items()) or "none")
        )
    if w["word_index_problems"]:
        result.append(
            "word index problems %d: %s"
            % (len(w["word_index_problems"]),
               ", ".join("%s ends at word %d of %d tokens" % (p["address"], p["highest_word_end"], p["tokens"])
                         for p in w["word_index_problems"]))
        )
    if s["missed"]:
        result.append("verdict FAIL: %s" % "; ".join(s["missed"]))
    else:
        result.append("verdict PASS")
    return result


def _audio_files(audio_dir):
    if not audio_dir.is_dir():
        raise PackError("the audio folder %s is not a folder" % audio_dir)
    found = []
    for path in sorted(audio_dir.iterdir()):
        match = _AUDIO_NAME.match(path.name)
        if match and path.is_file():
            found.append((path.name, (int(match.group(1)), int(match.group(2)))))
    if not found:
        raise PackError("the audio folder %s holds no SSSAAA.mp3 file" % audio_dir)
    return found


def _median(values):
    if not values:
        return None
    middle = len(values) // 2
    if len(values) % 2:
        return values[middle]
    return (values[middle - 1] + values[middle]) / 2.0


def _nearest_rank(values, percentile):
    return values[max(math.ceil(percentile / 100.0 * len(values)) - 1, 0)]


def _rounded(value):
    if isinstance(value, float):
        return round(value, 1) + 0.0
    if isinstance(value, dict):
        return {k: _rounded(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_rounded(v) for v in value]
    return value
