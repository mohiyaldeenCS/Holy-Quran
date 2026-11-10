"""Which linked entries ship, and the passages they become (D-186, D-184).

The gate: an entry of kind `passage` ships when the reviewer cleared it, or
when it has no review flag and its compare outcome is `same` or
`same_but_for_spelling`. An entry of kind `unlinked` that names a surah ships
as that surah's surah-level text (D-184) only when the reviewer cleared it:
by its own mark, or, when it has no review flag, by the record's clearance of
its surah's surah-level entries (bound by their hash, `ziydia_inputs`). An
exclusion overrides everything; every other kind never ships, book 514's
`above_the_rule` paragraphs among them.

A shipped entry's range is the union of its refs, checked against the P5
counts: a range below ayah 1, past its surah or reversed stops the build, and
a union that is not one interval is held out. In one surah, overlapping or
equal ranges merge in book order (touching ones do not), and all of a
surah's surah-level entries become its one surah-level passage. Passages are
sorted into mushaf order and numbered from 1; each one's text is its
paragraphs' texts, then the notes of its footnote marks in the marks' order
(D-189, `tafsir_footnotes`), joined by U+000A.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from .errors import PackError
from .tafsir_database import SURAH_LEVEL, PassageRow
from .ziydia_inputs import is_surah_level

CONFIRMED = ("same", "same_but_for_spelling")
JOIN = "\n"  # between a passage's paragraphs (D-184)


@dataclass(frozen=True)
class Held:
    n: int
    site_page: int
    reason: str  # excluded, flagged, not_cleared, gapped_range or a compare outcome


@dataclass(frozen=True)
class Chosen:
    n: int
    surah: int
    first: int  # SURAH_LEVEL for a surah-level entry
    last: int
    paragraphs: tuple  # (site_page, html), in the entry's order


@dataclass(frozen=True)
class Selection:
    chosen: list  # in book order
    held: list
    never: Counter  # kind -> entries of a kind that never ships


def select(entries, outcomes: dict, review, ayah_counts: dict) -> Selection:
    chosen, held, never = [], [], Counter()
    for entry in entries:
        n, kind, surah = entry["n"], entry["kind"], entry["surah"]
        site_page = entry["paragraphs"][0]["site_page"]
        if kind == "passage":
            reason = _passage_gate(entry, outcomes[n], review)
        elif is_surah_level(entry):
            reason = _surah_level_gate(entry, review)
        else:
            never[kind] += 1
            continue
        if reason is None and kind == "passage":
            first, last = _range(entry, ayah_counts)
            if first is None:
                reason = "gapped_range"
        elif reason is None:
            _surah(entry, ayah_counts)
            first = last = SURAH_LEVEL
        if reason is not None:
            held.append(Held(n, site_page, reason))
            continue
        paragraphs = tuple((p["site_page"], p["html"]) for p in entry["paragraphs"])
        chosen.append(Chosen(n, surah, first, last, paragraphs))
    return Selection(chosen, held, never)


def group(chosen) -> list:
    """The entries of each passage, in book order; the passages in mushaf order."""
    groups = {}
    for entry in chosen:
        if entry.first == SURAH_LEVEL:
            groups.setdefault((entry.surah, SURAH_LEVEL), []).append(entry)
    by_surah = {}
    for entry in chosen:
        if entry.first != SURAH_LEVEL:
            by_surah.setdefault(entry.surah, []).append(entry)
    for surah, entries in by_surah.items():
        for merged in _merged(entries):
            groups[(surah, min(e.first for e in merged))] = merged
    return [sorted(groups[key], key=lambda e: e.n) for key in sorted(groups)]


def assemble(chosen, texts: dict, marks=None, notes=None) -> list:
    """`texts` maps each chosen entry's n to its paragraphs' texts, the empty
    ones left out; `marks` maps it to its footnote marks [(site_page, N)] and
    `notes` each mark to its note's texts. Returns the passage rows, numbered
    in mushaf order."""
    marks, notes = marks or {}, notes or {}
    rows = []
    for number, entries in enumerate(group(chosen), 1):
        body = [text for e in entries for text in texts[e.n]]
        paragraphs = body + [text for e in entries for mark in marks.get(e.n, ()) for text in notes[mark]]
        surah, first = entries[0].surah, min(e.first for e in entries)
        if not body:
            raise PackError(
                "entries %s of surah %d have no text after conversion" % (", ".join(str(e.n) for e in entries), surah)
            )
        rows.append(PassageRow(number, surah, first, max(e.last for e in entries), JOIN.join(paragraphs)))
    if not rows:
        raise PackError("no passage is left to ship")
    return rows


def _passage_gate(entry, outcome, review):
    n = entry["n"]
    if n in review.excluded:
        return "excluded"
    if n in review.cleared:
        return None
    if "review" in entry:
        return "flagged"
    return None if outcome in CONFIRMED else outcome


def _surah_level_gate(entry, review):
    n = entry["n"]
    if n in review.excluded:
        return "excluded"
    if n in review.cleared:
        return None
    if "review" in entry:
        return "flagged"
    return None if entry["surah"] in review.cleared_surah_level else "not_cleared"


def _surah(entry, ayah_counts):
    surah = entry["surah"]
    if surah is None:
        raise PackError("entry %d is linked to ayat but names no surah" % entry["n"])
    if surah not in ayah_counts:
        raise PackError("entry %d: surah %d is not a surah of the ayah counts (1 to %d)" % (entry["n"], surah, len(ayah_counts)))
    return surah


def _range(entry, ayah_counts):
    """(first, last) of the union of the refs, or (None, None) when it is not one interval."""
    n, surah = entry["n"], _surah(entry, ayah_counts)
    if not entry["refs"]:
        raise PackError("entry %d is linked to ayat but has no range" % n)
    ayat = set()
    for first, last in entry["refs"]:
        if first < 1:
            raise PackError("entry %d: range %d..%d of surah %d starts below ayah 1" % (n, first, last, surah))
        if last < first:
            raise PackError("entry %d: range %d..%d of surah %d is reversed" % (n, first, last, surah))
        if last > ayah_counts[surah]:
            raise PackError(
                "entry %d reaches ayah %d of surah %d, which has %d" % (n, last, surah, ayah_counts[surah])
            )
        ayat.update(range(first, last + 1))
    low, high = min(ayat), max(ayat)
    if high - low + 1 != len(ayat):
        return None, None
    return low, high


def _merged(entries):
    """Groups of entries whose ranges overlap, directly or through another."""
    groups, reach = [], 0
    for entry in sorted(entries, key=lambda e: (e.first, e.n)):
        if groups and entry.first <= reach:
            groups[-1].append(entry)
            reach = max(reach, entry.last)
        else:
            groups.append([entry])
            reach = entry.last
    return groups
