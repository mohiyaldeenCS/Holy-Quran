"""quran-align word timing (registry row 6, CC BY 4.0, release 2016-11-24), read strictly.

The file is a JSON array of one object per ayah, in any order:
`{"surah", "ayah", "segments": [[word_start, word_end, start_ms, end_ms], ...],
"stats": {"insertions", "deletions", "transpositions"}}`. `word_end` is
exclusive; a word is a U+0020-separated token of Tanzil's quran-uthmani text; a
segment may cover several words and words may be missing; times are
milliseconds in that ayah's file. Every ayah of the profile must appear exactly
once. Errors name the entry's position, its address and a field, never a value
other than a number.

The real files hold a few segments whose times cannot be right, so the reader
keeps them and marks them instead of refusing the file (D-179): a segment is
defective, with each kind that applies, when it ends before it starts
(`end_before_start`), ends where it starts (`zero_length`), or starts before
the end of the segment just before it, defective or not (`overlap`). An entry
without the `segments` field, or with an empty list, is an ayah without
timing. Word indices are still checked on every segment.
"""

from __future__ import annotations

import json
from dataclasses import dataclass

from .errors import PackError

_FIELDS = frozenset(("surah", "ayah", "segments", "stats"))
_STATS = frozenset(("insertions", "deletions", "transpositions"))
_UNTIMED_FIELDS = _FIELDS - {"segments"}

END_BEFORE_START = "end_before_start"
ZERO_LENGTH = "zero_length"
OVERLAP = "overlap"


@dataclass(frozen=True)
class Segment:
    word_start: int
    word_end: int
    start_ms: int
    end_ms: int
    defects: tuple = ()


@dataclass(frozen=True)
class Timing:
    surah: int
    ayah: int
    segments: tuple
    segments_field: bool = True

    def sound(self) -> tuple:
        """The segments that are not defective, the only ones measured."""
        return tuple(s for s in self.segments if not s.defects)


def read_timing(data: bytes, profile, metadata=None) -> dict:
    """{(surah, ayah): Timing} for every ayah of `profile`; with `metadata`, the ayat per surah are the metadata's."""
    try:
        return _read(data, profile, metadata)
    except PackError as e:
        raise PackError("timing: %s" % e) from None


def _read(data, profile, metadata):
    if data.startswith(b"\xef\xbb\xbf"):
        raise PackError("the file begins with a UTF-8 BOM")
    try:
        document = data.decode("utf-8")
    except UnicodeDecodeError as e:
        raise PackError("malformed UTF-8 at byte %d" % e.start) from None
    try:
        entries = json.loads(
            document, object_pairs_hook=_object, parse_constant=_no_constant, parse_float=_no_float
        )
    except json.JSONDecodeError as e:
        raise PackError("invalid JSON at line %d column %d" % (e.lineno, e.colno)) from None
    if not isinstance(entries, list):
        raise PackError("the file is not a JSON array")
    result = {}
    for position, entry in enumerate(entries, 1):
        timing = _entry(entry, position, profile)
        address = (timing.surah, timing.ayah)
        if address in result:
            raise PackError("entry %d repeats %d:%d" % ((position,) + address))
        result[address] = timing
    _check_complete(result, profile, metadata)
    return result


def _entry(entry, position, profile):
    if not isinstance(entry, dict):
        raise PackError("entry %d is not an object" % position)
    if set(entry) not in (_FIELDS, _UNTIMED_FIELDS):
        raise PackError(
            "entry %d does not have exactly the fields %s (segments may be left out)"
            % (position, ", ".join(sorted(_FIELDS)))
        )
    surah = _integer(entry["surah"], "entry %d: surah" % position, 1)
    ayah = _integer(entry["ayah"], "entry %d: ayah" % position, 1)
    if surah > profile.surahs:
        raise PackError("entry %d names surah %d of %d" % (position, surah, profile.surahs))
    where = "entry %d (%d:%d)" % (position, surah, ayah)
    stats = entry["stats"]
    if not isinstance(stats, dict) or set(stats) != _STATS:
        raise PackError("%s: stats does not have exactly the fields %s" % (where, ", ".join(sorted(_STATS))))
    for name in sorted(_STATS):
        _integer(stats[name], "%s: stats.%s" % (where, name), 0)
    if "segments" not in entry:
        return Timing(surah=surah, ayah=ayah, segments=(), segments_field=False)
    segments = entry["segments"]
    if not isinstance(segments, list):
        raise PackError("%s: segments is not an array" % where)
    return Timing(surah=surah, ayah=ayah, segments=_segments(segments, where))


def _segments(values, where):
    result = []
    for number, value in enumerate(values, 1):
        label = "%s segment %d" % (where, number)
        if not isinstance(value, list) or len(value) != 4:
            raise PackError("%s is not an array of four integers" % label)
        word_start, word_end, start_ms, end_ms = (_integer(v, label, 0) for v in value)
        if word_end <= word_start:
            raise PackError("%s covers words %d to %d (end exclusive), no word" % (label, word_start, word_end))
        defects = []
        if end_ms < start_ms:
            defects.append(END_BEFORE_START)
        if result and start_ms < result[-1].end_ms:
            defects.append(OVERLAP)
        if end_ms == start_ms:
            defects.append(ZERO_LENGTH)
        if result:
            previous = result[-1]
            if word_start < previous.word_end:
                raise PackError(
                    "%s starts at word %d, before the previous segment's end word %d"
                    % (label, word_start, previous.word_end)
                )
        result.append(Segment(word_start, word_end, start_ms, end_ms, tuple(defects)))
    return tuple(result)


def _check_complete(result, profile, metadata):
    if len(result) != profile.ayat:
        raise PackError("the file has %d ayat, not %d" % (len(result), profile.ayat))
    counts = [0] * (profile.surahs + 1)
    for surah, _ in result:
        counts[surah] += 1
    for surah in range(1, profile.surahs + 1):
        expected = metadata.suras[surah - 1].ayas if metadata is not None else counts[surah]
        if counts[surah] == 0:
            raise PackError("the file has no ayah of surah %d" % surah)
        for ayah in range(1, expected + 1):
            if (surah, ayah) not in result:
                raise PackError("the file lacks %d:%d" % (surah, ayah))
        if counts[surah] != expected:
            raise PackError("surah %d has %d ayat in the file, %d in the metadata" % (surah, counts[surah], expected))


def _integer(value, label, minimum):
    if type(value) is not int:
        raise PackError("%s is not an integer" % label)
    if value < minimum:
        raise PackError("%s is %d, below %d" % (label, value, minimum))
    return value


def _object(pairs):
    names = [name for name, _ in pairs]
    if len(set(names)) != len(names):
        raise PackError("an object repeats a field name")
    return dict(pairs)


def _no_constant(name):
    raise PackError("the file holds %s, which is not JSON" % name)


def _no_float(text):
    raise PackError("the file holds a number with a fraction or exponent; every field is an integer")
