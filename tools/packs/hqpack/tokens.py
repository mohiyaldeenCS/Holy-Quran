"""Word and mark spans of an ayah (D-078, D-083, docs/CONTENT_PACKS.md).

Tokens are the maximal runs of characters other than U+0020. A token holding a
letter is a word, any other a mark. Offsets are UTF-16 code units, half-open.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass

from .errors import PackError, code_point

_SEPARATOR = 0x20
_REFUSED_CATEGORIES = ("Zs", "Zl", "Zp", "Cc", "Cs")


def utf16_length(s: str) -> int:
    return len(s.encode("utf-16-le")) // 2


def is_letter(cp: int) -> bool:
    return unicodedata.category(chr(cp)).startswith("L")


@dataclass(frozen=True)
class Spans:
    words: list
    marks: list


def spans(text: str, mark_code_points: frozenset, where: str) -> Spans:
    _check_characters(text, where)
    words = []
    marks = []
    offset = 0
    start = None
    token = []
    for c in text:
        cp = ord(c)
        if cp == _SEPARATOR:
            if start is not None:
                _add(token, start, offset, words, marks, mark_code_points, where)
                start = None
                token = []
        else:
            if start is None:
                start = offset
            token.append(cp)
        offset += _units(cp)
    if start is not None:
        _add(token, start, offset, words, marks, mark_code_points, where)
    return Spans(words=words, marks=marks)


def _units(cp: int) -> int:
    return 2 if cp > 0xFFFF else 1


def _check_characters(text: str, where: str) -> None:
    # The source must separate tokens with U+0020 only; anything else that
    # could act as a separator is refused, never rewritten.
    offset = 0
    for c in text:
        cp = ord(c)
        category = unicodedata.category(c)
        if cp != _SEPARATOR and category in _REFUSED_CATEGORIES:
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
