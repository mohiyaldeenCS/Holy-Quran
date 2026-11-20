"""Word and mark spans of an ayah (D-078, D-083, docs/CONTENT_PACKS.md).

Tokens are the maximal runs of characters other than U+0020. A token holding a
letter is a word, any other a mark. Offsets are UTF-16 code units, half-open.

A KFGQPC text is stored as published (D-198 Q4), so `presented_spans` adds two
rules. Its presentation, the ayah-end separator and number glyph and the
quarter sign and separator that open a quarter, are spans of their own at the
ayah's edges, cut by the table's rules; U+00A0 is accepted there and nowhere
else. And KFGQPC joins a pause mark to the word before it inside one token:
a run of JOINED_MARKS that ends a token holding a letter is cut off as a mark
at its offset, and one anywhere else in a word stops the build.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass

from .errors import PackError, code_point

_SEPARATOR = 0x20
_REFUSED_CATEGORIES = ("Zs", "Zl", "Zp", "Cc", "Cs")
# Format characters that act as invisible separators; other format characters
# (such as the joiners) may belong to a word and are kept.
_INVISIBLE_SEPARATORS = (0x200B, 0x2060)
# The pause marks U+06D6 to U+06DB and the sajda sign: the marks of D-078.
JOINED_MARKS = frozenset(range(0x06D6, 0x06DC)) | {0x06E9}


def is_letter(cp: int) -> bool:
    return unicodedata.category(chr(cp)).startswith("L")


def token_spans(text: str) -> list:
    """(start, end, is_word) of every token, in code points, half-open; nothing is
    refused, so it also serves a witness text that holds other white space."""
    result = []
    start = None
    for index, c in enumerate(text):
        if ord(c) == _SEPARATOR:
            if start is not None:
                result.append(_token(text, start, index))
                start = None
        elif start is None:
            start = index
    if start is not None:
        result.append(_token(text, start, len(text)))
    return result


def _token(text, start, end):
    return (start, end, any(is_letter(ord(c)) for c in text[start:end]))


@dataclass(frozen=True)
class Spans:
    words: list
    marks: list
    presentation: list  # [(after_word, start, end)]; none unless stored with its presentation


def spans(text: str, mark_code_points: frozenset, where: str) -> Spans:
    _check_characters(text, where, 0)
    words = []
    marks = []
    for token, start, end in _tokens(text, 0):
        _add(token, start, end, words, marks, mark_code_points, where)
    return Spans(words=words, marks=marks, presentation=[])


def presented_spans(text, mark_code_points, presentation, address, where) -> Spans:
    """The spans of a text stored with its presentation (D-198 Q4), cut by
    `presentation` (known_differences.Presentation); `address` is the
    ayah's (surah, number)."""
    opening = chr(presentation.quarter_sign) + chr(presentation.quarter_separator)
    separator = presentation.ayah_end_separators.get(address, presentation.ayah_end_separator)
    ending = chr(separator) + chr(presentation.first_number_glyph + address[1] - 1)
    if not text.endswith(ending):
        raise PackError(
            "%s does not end with %s %s, the ayah-end separator and the glyph of its number"
            % (where, code_point(ending[0]), code_point(ending[1]))
        )
    start = 0
    if text.startswith(opening[0]):
        if not text.startswith(opening):
            raise PackError(
                "%s opens with %s but not with %s %s"
                % (where, code_point(opening[0]), code_point(opening[0]), code_point(opening[1]))
            )
        start = len(opening)
    end = len(text) - len(ending)
    if end <= start:
        raise PackError("%s holds nothing but its presentation" % where)
    body = text[start:end]
    base = _length(text[:start])
    _check_characters(body, where, base)
    words = []
    marks = []
    for token, token_start, token_end in _tokens(body, base):
        _add_joined(token, token_start, token_end, words, marks, mark_code_points, where)
    body_end = base + _length(body)
    shown = [(0, 0, base)] if start else []
    shown.append((len(words), body_end, body_end + _length(ending)))
    return Spans(words=words, marks=marks, presentation=shown)


def _tokens(text, base):
    """(code points, start, end) of every maximal run of characters other
    than U+0020, in UTF-16 code units from `base`."""
    result = []
    offset = base
    start = None
    token = []
    for c in text:
        cp = ord(c)
        if cp == _SEPARATOR:
            if start is not None:
                result.append((token, start, offset))
                start = None
                token = []
        else:
            if start is None:
                start = offset
            token.append(cp)
        offset += _units(cp)
    if start is not None:
        result.append((token, start, offset))
    return result


def _units(cp: int) -> int:
    return 2 if cp > 0xFFFF else 1


def _length(text: str) -> int:
    return sum(_units(ord(c)) for c in text)


def _check_characters(text: str, where: str, base: int) -> None:
    # The source must separate tokens with U+0020 only; anything else that
    # could act as a separator is refused, never rewritten.
    offset = base
    for c in text:
        cp = ord(c)
        category = unicodedata.category(c)
        if cp != _SEPARATOR and (
            category in _REFUSED_CATEGORIES or cp in _INVISIBLE_SEPARATORS
        ):
            raise PackError(
                "%s holds %s (category %s) at offset %d; only U+0020 may "
                "separate tokens" % (where, code_point(cp), category, offset)
            )
        offset += _units(cp)


def _add(token, start, end, words, marks, mark_code_points, where):
    if any(is_letter(cp) for cp in token):
        words.append((start, end))
        return
    number = len(marks) + 1
    for cp in token:
        if cp not in mark_code_points:
            raise PackError(
                "%s mark %d holds %s, which is not in the mark table"
                % (where, number, code_point(cp))
            )
    marks.append((len(words), start, end))


def _add_joined(token, start, end, words, marks, mark_code_points, where):
    """A token holding a letter: the run of JOINED_MARKS that ends it, if
    any, is a mark of its own after the word."""
    if not any(is_letter(cp) for cp in token):
        _add(token, start, end, words, marks, mark_code_points, where)
        return
    cut = len(token)
    while token[cut - 1] in JOINED_MARKS:
        cut -= 1
    for cp in token[:cut]:
        if cp in JOINED_MARKS:
            raise PackError(
                "%s word %d holds %s before the end of its token; only a mark "
                "that ends a token is cut from its word"
                % (where, len(words) + 1, code_point(cp))
            )
    middle = start + sum(_units(cp) for cp in token[:cut])
    words.append((start, middle))
    if cut < len(token):
        _add(token[cut:], middle, end, words, marks, mark_code_points, where)
