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
    boundaries = [(a.end_ms + b.start_ms) / 2.0 for a, b in zip(segments, segments[1:])]
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
        "timing_end_ms": segments[-1].end_ms if segments else None,
        "end_check": "pass",
        "speech_onset_ms": found.onset_ms,
        "onset_ms": None,
        "pauses": len(found.pauses),
        "samples": [],
    }
    if segments and segments[-1].end_ms > audio.duration_ms + audio.frame_ms:
        result["end_check"] = "fail"
    if segments and found.onset_ms is not None:
        result["onset_ms"] = segments[0].start_ms - found.onset_ms
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


def summarise(files, entries) -> dict:
    samples = [(s["at_ms"], s["offset_ms"]) for f in files for s in f["samples"]]
    offsets = [o for _, o in samples]
    magnitudes = sorted(abs(o) for o in offsets)
    onsets = sorted(f["onset_ms"] for f in files if f["onset_ms"] is not None)
    summary = {
        "files_measured": len(files),
        "entries_without_file": entries - len(files),
        "end_check_failures": sum(1 for f in files if f["end_check"] == "fail"),
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
        for s in segments:
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
    for name, address in _audio_files(audio_dir):
        if address not in timings:
            raise PackError("%s names %d:%d, which the timing file does not have" % ((name,) + address))
        data = (audio_dir / name).read_bytes()
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
        "summary": summarise(files, len(timings)),
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
            "%s %s sha256 %s: duration %s ms (delay %s, LAME tag %s), timing end %s ms, end check %s, "
            "onset %s ms, pauses %d, samples %d"
            % (
                f["file"], f["address"], f["sha256"], f["duration_ms"],
                "known" if f["delay_known"] else "not known", f["lame_tag"], f["timing_end_ms"], f["end_check"],
                f["onset_ms"], f["pauses"], len(f["samples"]),
            )
        )
    s = report["summary"]
    w = report["words"]
    result.extend(
        [
            "files measured %d, entries without a file %d, end-check failures %d"
            % (s["files_measured"], s["entries_without_file"], s["end_check_failures"]),
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
