"""Tanzil's tokens to KFGQPC's words per ayah, and quran-align timing re-indexed onto them (B0.5, D-195, D-198, PRD 10.4).

quran-align counts words as the U+0020 tokens of Tanzil's quran-uthmani text, from 0
(`quran_align.py`). The base text is KFGQPC's (D-195). Its words are those of the
`word` table: the U+0020 tokens of the ayah once the table's presentation rules are
removed (`compare.Alignment.body`) that hold a letter, numbered from 1 (D-078,
D-083); a token with no letter is a mark.

The map is read off the comparison's own alignment (`compare.Aligner`): a Tanzil token
goes to the KFGQPC token that holds the code points matched to it as equal, carried
back through the equivalences. Accepted, and nothing else:

- a Tanzil word goes to one KFGQPC word, and each KFGQPC word receives exactly one
  Tanzil word;
- a Tanzil mark goes to the one KFGQPC word that holds its matched code points
  (`joined`: KFGQPC writes the pause mark inside the word), or to no word, where they
  fall in a KFGQPC mark (`apart`) or nothing matches them (`unmatched`).

Map problems, all collected: `unmatched_word` (a Tanzil word with no code point
matched), `ambiguous` (a token whose matched code points fall in two KFGQPC tokens or
more), `word_in_mark` (a Tanzil word that falls in a KFGQPC mark), `shared_word` (a
KFGQPC word that receives two Tanzil words or more), `unmapped_word` (one that
receives none) and `presentation` (an ayah whose presentation the table could not
remove). An ayah with a problem has no map.

A segment's KFGQPC words are those of the Tanzil words it covers. A segment that
covers marks only belongs to the word they are joined to or, when they go to no word,
to the word before them (D-078, D-201), and is merged into the segment just before
it, which must cover that word; the merged segment ends where the mark's segment ends
and carries the defects of both. Timing problems: `lone_mark` (that word has no
segment just before), `no_word_before` (marks that go to no word, with no word before
them), `ambiguous_segment` (marks joined to two words), `past_the_ayah` (the segment
ends past the ayah's tokens, D-182) and `unmapped_ayah` (a timed ayah without a map).
Every problem stops (PRD 10.4); none is resolved here. Problems and counts name
addresses, numbers and kinds, never a character.
"""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple, Optional

from . import compare, digest, kfgqpc
from .errors import PackError
from .known_differences import read_table
from .quran_align import END_BEFORE_START, OVERLAP, ZERO_LENGTH, read_timing
from .source_checks import check_structure
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .tokens import token_spans

FIRST_ADDRESSES = 10
_TOKEN_PROBLEMS = ("unmatched_word", "ambiguous", "word_in_mark")
_DEFECTS = (END_BEFORE_START, OVERLAP, ZERO_LENGTH)
_MAP_COUNTS = (
    "ayat", "tanzil_tokens", "tanzil_words", "tanzil_marks", "marks_joined", "marks_apart", "marks_unmatched",
    "kfgqpc_words",
)
_TIMING_COUNTS = (
    "ayat", "ayat_without_timing", "segments", "merged_joined_mark_segments", "merged_wordless_mark_segments",
    "kfgqpc_segments",
)


class Token(NamedTuple):
    """A Tanzil token: the KFGQPC word it goes to, from 1 (None for a mark that goes to no word), and whether it holds a letter."""

    word: Optional[int]
    is_word: bool


@dataclass(frozen=True)
class AyahMap:
    """The ayah's number of KFGQPC words, and a Token for each Tanzil token, from 0."""

    words: int
    tokens: tuple


@dataclass(frozen=True)
class WordSegment:
    """A timing segment over KFGQPC words `first_word` to `last_word`, both included, numbered from 1."""

    first_word: int
    last_word: int
    start_ms: int
    end_ms: int
    defects: tuple = ()


@dataclass(frozen=True)
class WordTiming:
    surah: int
    ayah: int
    segments: tuple
    segments_field: bool = True


def map_words(text, witness, table):
    """({(surah, ayah): AyahMap}, problems, counts) of the parsed Tanzil text and KFGQPC ayat under `table`."""
    tanzil = [(aya.surah, aya.number, aya.text.value) for sura in text.suras for aya in sura.ayat]
    compare.check_addresses(tanzil, witness)
    # The metadata's quarter starts feed only the comparison's quarter records, which the map does not read.
    aligner = compare.Aligner(table, frozenset())
    maps = {}
    problems = []
    counts = OrderedDict((key, 0) for key in _MAP_COUNTS)
    counts["ayat"] = len(tanzil)
    for (surah, number, tanzil_text), aya in zip(tanzil, witness):
        address = (surah, number)
        before = len(aligner.presentation_problems)
        alignment = aligner.align(address, aya.text, tanzil_text)
        if len(aligner.presentation_problems) > before:
            problems.append(_problem(address, "presentation"))
            continue
        ayah_map = _ayah_map(address, alignment, tanzil_text, problems, counts)
        if ayah_map is not None:
            maps[address] = ayah_map
    return maps, problems, counts


def reindex(timings, maps):
    """({(surah, ayah): WordTiming}, problems, counts): each ayah of `timings` whose segments all re-index."""
    result = {}
    problems = []
    counts = OrderedDict((key, 0) for key in _TIMING_COUNTS)
    for address in sorted(timings):
        timing = timings[address]
        counts["ayat"] += 1
        found = len(problems)
        segments = ()
        if not timing.segments:
            counts["ayat_without_timing"] += 1
        elif address not in maps:
            problems.append(_problem(address, "unmapped_ayah"))
        else:
            segments = _segments(address, timing.segments, maps[address], problems, counts)
        if len(problems) == found:
            result[address] = WordTiming(address[0], address[1], segments, timing.segments_field)
            counts["kfgqpc_segments"] += len(segments)
    return result, problems, counts


def run_word_map(text_path, metadata_path, kfgqpc_path, table_path, timing_paths, profile):
    """The map of the two texts under the table and the re-indexing of each timing file: counts, problems and the inputs' SHA-256."""
    text_bytes = Path(text_path).read_bytes()
    metadata_bytes = Path(metadata_path).read_bytes()
    text = read_tanzil_text(text_bytes)
    metadata = read_tanzil_metadata(metadata_bytes)
    check_structure(profile, text, metadata)
    witness, kfgqpc_sha256 = kfgqpc.read_kfgqpc_file(kfgqpc_path, profile.ayat)
    table_bytes = Path(table_path).read_bytes()
    table = read_table(table_bytes)
    maps, problems, counts = map_words(text, witness, table)
    report = OrderedDict()
    report["inputs"] = OrderedDict(
        [
            ("tanzil_text_sha256", digest.sha256_bytes(text_bytes)),
            ("tanzil_metadata_sha256", digest.sha256_bytes(metadata_bytes)),
            ("kfgqpc_sha256", kfgqpc_sha256),
            ("table_version", table.version),
            ("table_sha256", digest.sha256_bytes(table_bytes)),
        ]
    )
    report["map"] = OrderedDict([("counts", counts), ("problems", _grouped(problems))])
    report["timings"] = []
    for path in timing_paths:
        data = Path(path).read_bytes()
        _, timing_problems, timing_counts = reindex(read_timing(data, profile, metadata), maps)
        report["timings"].append(
            OrderedDict(
                [
                    ("sha256", digest.sha256_bytes(data)),
                    ("counts", timing_counts),
                    ("problems", _grouped(timing_problems)),
                ]
            )
        )
    report["passed"] = not problems and not any(t["problems"] for t in report["timings"])
    return report


def lines(report):
    """The report as ASCII lines: hashes, counts, problem kinds and at most FIRST_ADDRESSES addresses each."""
    result = ["%s %s" % (key.replace("_", " "), value) for key, value in report["inputs"].items()]
    result.append("word map: " + _counts(report["map"]["counts"]))
    result.extend(_problem_lines(report["map"]["problems"]))
    for number, timing in enumerate(report["timings"], 1):
        result.append("timing %d sha256 %s: %s" % (number, timing["sha256"], _counts(timing["counts"])))
        result.extend(_problem_lines(timing["problems"]))
    result.append("passed" if report["passed"] else "problems found: the timing cannot be put on KFGQPC words")
    for line in result:
        if not line.isascii():
            raise PackError("a word-map line holds a character outside ASCII; it is not printed")
    return result


def _ayah_map(address, alignment, tanzil_text, problems, counts):
    """The ayah's AyahMap, or None when it adds a problem to `problems`; `counts` gains its tokens."""
    found = len(problems)
    kfgqpc_tokens = token_spans(alignment.body)
    numbers = {}
    for index, (_, _, is_word) in enumerate(kfgqpc_tokens):
        if is_word:
            numbers[index] = len(numbers) + 1
    token_at = _token_at(len(alignment.body), kfgqpc_tokens)
    matched = _matched(alignment, len(tanzil_text))
    tokens = []
    for index, (start, end, is_word) in enumerate(token_spans(tanzil_text)):
        word, kind = _target(_hits(matched[start:end], token_at), numbers, is_word)
        if kind in _TOKEN_PROBLEMS:
            problems.append(_problem(address, kind, tanzil_token=index))
        elif kind is not None:
            counts[kind] += 1
        counts["tanzil_tokens"] += 1
        counts["tanzil_words" if is_word else "tanzil_marks"] += 1
        tokens.append(Token(word, is_word))
    problems.extend(_receiver_problems(address, len(numbers), tokens))
    counts["kfgqpc_words"] += len(numbers)
    if len(problems) > found:
        return None
    return AyahMap(words=len(numbers), tokens=tuple(tokens))


def _hits(matched, token_at):
    """The KFGQPC tokens, sorted, that hold the code points matched to one Tanzil token."""
    return sorted(
        {token_at[i] for match in matched if match is not None for i in range(*match) if token_at[i] is not None}
    )


def _receiver_problems(address, words, tokens):
    """A problem for each KFGQPC word that does not receive exactly one Tanzil word."""
    receivers = {}
    for index, token in enumerate(tokens):
        if token.is_word and token.word is not None:
            receivers.setdefault(token.word, []).append(index)
    result = []
    for word in range(1, words + 1):
        given = receivers.get(word, [])
        if not given:
            result.append(_problem(address, "unmapped_word", kfgqpc_word=word))
        elif len(given) > 1:
            result.append(_problem(address, "shared_word", kfgqpc_word=word, tanzil_tokens=given))
    return result


def _target(hit, numbers, is_word):
    """(KFGQPC word or None, what happened) for a Tanzil token whose matched code points fall in the KFGQPC tokens `hit`."""
    if not hit:
        return None, "unmatched_word" if is_word else "marks_unmatched"
    if len(hit) > 1:
        return None, "ambiguous"
    if hit[0] not in numbers:
        return None, "word_in_mark" if is_word else "marks_apart"
    return numbers[hit[0]], None if is_word else "marks_joined"


def _token_at(length, spans):
    """For each code point of a text of `length`, the index of its token, or None for a U+0020."""
    result = [None] * length
    for index, (start, end, _) in enumerate(spans):
        result[start:end] = [index] * (end - start)
    return result


def _matched(alignment, length):
    """For each code point of the Tanzil ayah, the range of `body` matched to it as equal, or None."""
    result = [None] * length
    for tag, i1, i2, j1, _ in alignment.opcodes:
        if tag == "equal":
            for offset in range(i2 - i1):
                i = i1 + offset
                result[j1 + offset] = (i, i + 1) if alignment.origin is None else alignment.origin[i]
    return result


def _segments(address, segments, ayah_map, problems, counts):
    result = []
    for number, segment in enumerate(segments, 1):
        counts["segments"] += 1
        if segment.word_end > len(ayah_map.tokens):
            problems.append(
                _problem(
                    address, "past_the_ayah", segment=number, word_end=segment.word_end,
                    tanzil_tokens=len(ayah_map.tokens),
                )
            )
            continue
        covered = ayah_map.tokens[segment.word_start:segment.word_end]
        own = [token.word for token in covered if token.is_word]
        if own:
            result.append(WordSegment(own[0], own[-1], segment.start_ms, segment.end_ms, segment.defects))
            continue
        word, kind = _mark_word(ayah_map.tokens, segment)
        if word is None:
            problems.append(_problem(address, kind, segment=number))
        elif not result or not result[-1].first_word <= word <= result[-1].last_word:
            problems.append(_problem(address, "lone_mark", segment=number, kfgqpc_word=word))
        else:
            result[-1] = _merged(result[-1], segment)
            counts[kind] += 1
    return tuple(result)


def _mark_word(tokens, segment):
    """(the KFGQPC word of a segment over marks only, the count its merge adds to), or (None, its problem):
    the word its marks are joined to, else the word before them (D-078, D-201)."""
    covered = tokens[segment.word_start:segment.word_end]
    joined = sorted({token.word for token in covered if token.word is not None})
    if len(joined) > 1:
        return None, "ambiguous_segment"
    if joined:
        return joined[0], "merged_joined_mark_segments"
    before = [token.word for token in tokens[:segment.word_start] if token.is_word]
    if not before:
        return None, "no_word_before"
    return before[-1], "merged_wordless_mark_segments"


def _merged(segment, mark_segment):
    defects = tuple(kind for kind in _DEFECTS if kind in segment.defects or kind in mark_segment.defects)
    return WordSegment(segment.first_word, segment.last_word, segment.start_ms, mark_segment.end_ms, defects)


def _problem(address, kind, **numbers):
    return OrderedDict([("address", "hafs:%d:%d" % address), ("kind", kind)] + list(numbers.items()))


def _grouped(problems):
    """{kind: {"count", "first": the first FIRST_ADDRESSES distinct addresses}}, kinds sorted."""
    result = OrderedDict()
    for problem in problems:
        entry = result.setdefault(problem["kind"], OrderedDict([("count", 0), ("first", [])]))
        entry["count"] += 1
        if problem["address"] not in entry["first"] and len(entry["first"]) < FIRST_ADDRESSES:
            entry["first"].append(problem["address"])
    return OrderedDict(sorted(result.items()))


def _counts(counts):
    return ", ".join("%s %d" % (key.replace("_", " "), value) for key, value in counts.items())


def _problem_lines(grouped):
    return [
        "problem %s %d, first %s" % (kind, entry["count"], " ".join(entry["first"]))
        for kind, entry in grouped.items()
    ]
