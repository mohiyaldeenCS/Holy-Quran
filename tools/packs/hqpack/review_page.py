"""The reciter's review page for the KFGQPC comparison (B0.2, D-176, D-178).

Runs the comparison (compare.py, the same code as `pack.py compare`) and writes
into an empty folder outside every Git working tree one self-contained
`review.html` and copies of the two fonts. Every text on the page is a whole
ayah as its source has it, drawn in its source's font: the Tanzil ayah in Amiri
Quran, the KFGQPC ayah, presentation signs included, in KFGQPC's own font. The
differing word is marked by slicing at token offsets only; the three slices
must join to the source text exactly, or nothing is written.

Sections (D-178): A, every difference that involves a pause mark or belongs to
a pattern seen at most RARE_COUNT times; B, one card per other pattern; C, the
space that stands before a pause mark in one source only; D, the division
differences and the surah openings P-3 accepts as quarter starts.
"""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path

from . import compare, review_html
from .build import FONT_FAMILY
from .digest import sha256_bytes
from .errors import PackError, code_point
from .font import read_font
from .git_tree import git_tree
from .options import PAUSE_MARKS
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text

PAGE_FILE = "review.html"
TANZIL_FONT_FILE = "font-tanzil.ttf"
KFGQPC_FONT_FILE = "font-kfgqpc.ttf"
KFGQPC_FONT_NAME = "uthmanic_hafs_v20.ttf"
RARE_COUNT = 3
SPACE = " "
# HTML parsing turns these into other characters, so a text holding one could not be shown unchanged.
_NOT_SHOWABLE = (0x0000, 0x000D)
_PAUSE = frozenset(chr(cp) for cp in PAUSE_MARKS)


@dataclass(frozen=True)
class Card:
    """One pattern of section B or C: its two sequences and every place of it there."""

    kfgqpc: str
    tanzil: str
    places: tuple


@dataclass(frozen=True)
class Sections:
    a: tuple
    b: tuple
    c: tuple


@dataclass(frozen=True)
class ReviewResult:
    directory: Path
    report: dict
    sections: Sections
    surah_opening_quarters: tuple
    inputs: dict


def write_review_page(text_path, metadata_path, kfgqpc_path, table_path, tanzil_font, kfgqpc_font, out, profile):
    """Compares, renders and writes the page; refuses before writing anything."""
    out = Path(out)
    _check_out(out)
    tanzil_font = Path(tanzil_font)
    kfgqpc_font = Path(kfgqpc_font)
    if kfgqpc_font.name != KFGQPC_FONT_NAME:
        raise PackError("the KFGQPC font is not named %s, as in KFGQPC's zip" % KFGQPC_FONT_NAME)
    tanzil_font_bytes = tanzil_font.read_bytes()
    kfgqpc_font_bytes = kfgqpc_font.read_bytes()
    tanzil_font_info = read_font(tanzil_font_bytes)
    kfgqpc_font_info = read_font(kfgqpc_font_bytes)
    if tanzil_font_info.family != FONT_FAMILY:
        raise PackError("the Tanzil font is not %s, the font the app draws the Tanzil text with" % FONT_FAMILY)

    text_bytes = Path(text_path).read_bytes()
    metadata_bytes = Path(metadata_path).read_bytes()
    text = read_tanzil_text(text_bytes)
    metadata = read_tanzil_metadata(metadata_bytes)
    tanzil_sha256 = {"text": sha256_bytes(text_bytes), "metadata": sha256_bytes(metadata_bytes)}
    trace = compare.Trace()
    report = compare.run_comparison(text, metadata, kfgqpc_path, table_path, profile, tanzil_sha256, trace)

    sections = classify(trace.places)
    shown = _shown_places(sections)
    _check_showable(shown)
    _check_coverage(tanzil_font_info, ((p.address, p.tanzil_text) for p in shown), "Tanzil")
    _check_coverage(kfgqpc_font_info, ((p.address, p.kfgqpc_text) for p in shown), "KFGQPC")

    inputs = OrderedDict(
        [
            ("tanzil_text_sha256", report["tanzil"]["text_sha256"]),
            ("tanzil_metadata_sha256", report["tanzil"]["metadata_sha256"]),
            ("kfgqpc_file", report["kfgqpc"]["file"]),
            ("kfgqpc_version", report["kfgqpc"]["version"]),
            ("kfgqpc_sha256", report["kfgqpc"]["sha256"]),
            ("table_version", report["table"]["version"]),
            ("table_sha256", report["table"]["sha256"]),
            ("tanzil_font_sha256", tanzil_font_info.sha256),
            ("kfgqpc_font_sha256", kfgqpc_font_info.sha256),
        ]
    )
    names = {sura.index: sura.name.value for sura in metadata.suras}
    page = review_html.render(
        review_html.Page(
            report=report,
            sections=sections,
            surah_opening_quarters=tuple(trace.surah_opening_quarters),
            surah_names=names,
            inputs=inputs,
            fonts=(TANZIL_FONT_FILE, KFGQPC_FONT_FILE),
        )
    )

    page_bytes = page.encode("utf-8")
    out.mkdir(parents=True, exist_ok=True)
    (out / TANZIL_FONT_FILE).write_bytes(tanzil_font_bytes)
    (out / KFGQPC_FONT_FILE).write_bytes(kfgqpc_font_bytes)
    (out / PAGE_FILE).write_bytes(page_bytes)
    return ReviewResult(
        directory=out,
        report=report,
        sections=sections,
        surah_opening_quarters=tuple(trace.surah_opening_quarters),
        inputs=inputs,
    )


def classify(places):
    """Each place in exactly one section; places keep the comparison's order, and
    cards are sorted as the report's patterns are: by count, then by code points."""
    in_c = OrderedDict()
    rest = OrderedDict()
    for place in places:
        groups = in_c if is_space_before_pause_mark(place) else rest
        groups.setdefault((place.kfgqpc_sequence, place.tanzil_sequence), []).append(place)
    a_keys = {
        key for key, group in rest.items() if _has_pause_mark(key) or len(group) <= RARE_COUNT
    }
    return Sections(
        a=tuple(p for p in places if (p.kfgqpc_sequence, p.tanzil_sequence) in a_keys and not is_space_before_pause_mark(p)),
        b=_cards((key, group) for key, group in rest.items() if key not in a_keys),
        c=_cards(in_c.items()),
    )


def is_space_before_pause_mark(place):
    """One source has a lone U+0020 where the other has nothing, and a pause mark follows it."""
    if (place.kfgqpc_sequence, place.tanzil_sequence) == ("", SPACE):
        return _pause_at(place.tanzil_text, place.tanzil[1])
    if (place.kfgqpc_sequence, place.tanzil_sequence) == (SPACE, ""):
        return _pause_at(place.kfgqpc_text, place.kfgqpc[1])
    return False


def _cards(groups):
    cards = [Card(kfgqpc=key[0], tanzil=key[1], places=tuple(group)) for key, group in groups]
    return tuple(
        sorted(cards, key=lambda c: (-len(c.places), [ord(x) for x in c.kfgqpc], [ord(x) for x in c.tanzil]))
    )


def _has_pause_mark(key):
    return any(c in _PAUSE for c in key[0] + key[1])


def _pause_at(text, index):
    return index < len(text) and text[index] in _PAUSE


def _shown_places(sections):
    shown = list(sections.a)
    for card in sections.b:
        shown.extend(review_html.examples(card.places, review_html.EXAMPLES_B))
    for card in sections.c:
        shown.extend(review_html.examples(card.places, review_html.EXAMPLES_C))
    return shown


def _check_out(out):
    tree = git_tree(out)
    if tree is not None:
        raise PackError(
            "the output folder %s is inside the Git working tree %s; the page holds Quran text "
            "and is written outside every repository" % (out, tree)
        )
    if out.exists():
        if not out.is_dir():
            raise PackError("the output %s exists and is not a folder" % out)
        if any(out.iterdir()):
            raise PackError("the output folder %s is not empty; give a new or empty folder" % out)


def _check_showable(places):
    for place in places:
        for source, text in (("Tanzil", place.tanzil_text), ("KFGQPC", place.kfgqpc_text)):
            for cp in _NOT_SHOWABLE:
                if chr(cp) in text:
                    raise PackError(
                        "the %s text of hafs:%d:%d holds %s, which HTML would not show unchanged"
                        % ((source,) + place.address + (code_point(cp),))
                    )


def _check_coverage(font, texts, source):
    """Every code point shown in `source`'s font is in it, so no browser draws one with another font."""
    missing = OrderedDict()
    for address, text in texts:
        for c in text:
            if ord(c) not in font.code_points:
                missing.setdefault(ord(c), address)
    if missing:
        raise PackError(
            "the %s font lacks %s"
            % (
                source,
                ", ".join(
                    "%s (first in hafs:%d:%d)" % ((code_point(cp),) + address)
                    for cp, address in sorted(missing.items())
                ),
            )
        )
