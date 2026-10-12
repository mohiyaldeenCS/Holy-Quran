"""Word and mark spans and font coverage, recomputed from the stored text
by the D-083 rule, for the independent verifier."""

from __future__ import annotations

import struct
import unicodedata

from .errors import code_point

_SEPARATORS = ("Zs", "Zl", "Zp", "Cc")


def _code_units(text):
    data = text.encode("utf-16-le")
    return struct.unpack("<%dH" % (len(data) // 2), data)


def _code_point_at(units, offset):
    unit = units[offset]
    if 0xD800 <= unit < 0xDC00 and offset + 1 < len(units):
        low = units[offset + 1]
        if 0xDC00 <= low < 0xE000:
            return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
    return unit


def _is_letter(cp):
    return unicodedata.category(chr(cp)).startswith("L")


def _tokens(text):
    """(start, end, is_word, code points) of every maximal run of characters
    other than U+0020, in UTF-16 code units."""
    tokens = []
    offset = 0
    start = None
    points = []
    for ch in text + " ":
        if ch == " ":
            if start is not None:
                tokens.append((start, offset, any(map(_is_letter, points)),
                               points))
                start = None
        else:
            if start is None:
                start = offset
                points = []
            points.append(ord(ch))
        offset += 2 if ord(ch) > 0xFFFF else 1
    return tokens


def all_span_problems(pack, texts, mark_code_points, problems):
    outside = {}
    for surah, number, _ in pack.ayat:
        where = "ayah %d:%d" % (surah, number)
        text = texts.get(where)
        if text is None:
            continue
        words = pack.words.get((surah, number), [])
        marks = pack.marks.get((surah, number), [])
        tokens = _tokens(text)
        _separator_problems(where, text, problems)
        _recomputed_problems(where, tokens, words, marks, problems)
        units = _code_units(text)
        _order_problems(where, units, words, marks, problems)
        _token_problems(where, units, words, marks, problems)
        _gap_problems(where, units, words, marks, problems)
        _letter_problems(where, units, words, marks, problems)
        if mark_code_points is not None:
            for _, _, is_word, points in tokens:
                for cp in points:
                    if not is_word and cp not in mark_code_points:
                        outside.setdefault(cp, where)
    for cp in sorted(outside):
        problems.append(
            "%s is in a mark but not in the mark table; first at %s"
            % (code_point(cp), outside[cp]))


def _separator_problems(where, text, problems):
    offset = 0
    for ch in text:
        if ch != " " and unicodedata.category(ch) in _SEPARATORS:
            problems.append(
                "%s: %s at offset %d is a separator other than U+0020"
                % (where, code_point(ch), offset))
        offset += 2 if ord(ch) > 0xFFFF else 1


def _recomputed_problems(where, tokens, words, marks, problems):
    expected_words = []
    expected_marks = []
    for start, end, is_word, _ in tokens:
        if is_word:
            expected_words.append((len(expected_words) + 1, start, end))
        else:
            expected_marks.append(
                (len(expected_marks) + 1, len(expected_words), start, end))
    _row_differences(where, "word", words, expected_words, problems)
    _row_differences(where, "mark", marks, expected_marks, problems)


def _describe(kind, row, index):
    span = "%d..%d" % row[-2:]
    if kind == "mark":
        span += " after word %d" % row[1]
    if row[0] != index + 1:
        span = "number %d, %s" % (row[0], span)
    return span


def _row_differences(where, kind, stored, expected, problems):
    for index in range(max(len(stored), len(expected))):
        found = stored[index] if index < len(stored) else None
        given = expected[index] if index < len(expected) else None
        if found == given:
            continue
        if given is None:
            problems.append(
                "%s: %s %d is stored as %s; the text has no %s %d"
                % (where, kind, index + 1, _describe(kind, found, index),
                   kind, index + 1))
        elif found is None:
            problems.append(
                "%s: the text gives %s %d as %s; it is not stored"
                % (where, kind, index + 1, _describe(kind, given, index)))
        else:
            problems.append(
                "%s: %s %d is stored as %s, the text gives %s"
                % (where, kind, index + 1, _describe(kind, found, index),
                   _describe(kind, given, index)))


def _spans(words, marks):
    """(kind, number, start, end) of every stored span."""
    return ([("word", n, s, e) for n, s, e in words]
            + [("mark", n, s, e) for n, _, s, e in marks])


def _in_bounds(units, start, end):
    return 0 <= start < end <= len(units)


def _splits_pair(units, offset):
    return (0 < offset < len(units)
            and 0xD800 <= units[offset - 1] < 0xDC00
            and 0xDC00 <= units[offset] < 0xE000)


def _order_problems(where, units, words, marks, problems):
    """Numbering, order, bounds, surrogate pairs and after_word, walking the
    stored words and marks together in text order."""
    for kind, rows in (("word", words), ("mark", marks)):
        for index, row in enumerate(rows):
            if row[0] != index + 1:
                problems.append(
                    "%s: %s %d is numbered %d" % (where, kind, index + 1,
                                                 row[0]))
    previous_end = 0
    w = m = 0
    while w < len(words) or m < len(marks):
        is_word = m == len(marks) or (
            w < len(words) and words[w][1] <= marks[m][2])
        if is_word:
            kind, (number, start, end) = "word", words[w]
            w += 1
        else:
            kind, (number, after, start, end) = "mark", marks[m]
            if after != w:
                problems.append(
                    "%s: mark %d has after_word %d; %d words come before it"
                    % (where, number, after, w))
            m += 1
        name = "%s: %s %d span %d..%d" % (where, kind, number, start, end)
        if start >= end:
            problems.append("%s is empty or reversed" % name)
            continue
        if start < 0 or end > len(units):
            problems.append(
                "%s lies outside the %d code units of the ayah"
                % (name, len(units)))
            continue
        if start < previous_end:
            problems.append(
                "%s overlaps or precedes the span before it, which ends at %d"
                % (name, previous_end))
        for offset in (start, end):
            if _splits_pair(units, offset):
                problems.append(
                    "%s: offset %d splits a surrogate pair" % (name, offset))
        previous_end = end


def _token_problems(where, units, words, marks, problems):
    for kind, number, start, end in _spans(words, marks):
        if not _in_bounds(units, start, end):
            continue
        name = "%s: %s %d span %d..%d" % (where, kind, number, start, end)
        if 0x20 in units[start:end]:
            problems.append("%s holds U+0020" % name)
        if start > 0 and units[start - 1] != 0x20:
            problems.append("%s does not start a token" % name)
        if end < len(units) and units[end] != 0x20:
            problems.append("%s does not end a token" % name)


def _gap_problems(where, units, words, marks, problems):
    covered = [False] * len(units)
    for _, _, start, end in _spans(words, marks):
        for i in range(max(start, 0), min(end, len(units))):
            covered[i] = True
    i = 0
    while i < len(units):
        if covered[i]:
            i += 1
            continue
        other = None
        while i < len(units) and not covered[i]:
            if other is None and units[i] != 0x20:
                other = i
            i += 1
        if other is not None:
            problems.append(
                "%s: offset %d holds %s outside every word and mark"
                % (where, other, code_point(_code_point_at(units, other))))


def _first_letter(units, start, end):
    for i in range(start, end):
        if _is_letter(_code_point_at(units, i)):
            return i
    return None


def _letter_problems(where, units, words, marks, problems):
    for number, start, end in words:
        if _in_bounds(units, start, end) and (
                _first_letter(units, start, end) is None):
            problems.append(
                "%s: word %d span %d..%d holds no letter"
                % (where, number, start, end))
    for number, _, start, end in marks:
        if not _in_bounds(units, start, end):
            continue
        at = _first_letter(units, start, end)
        if at is not None:
            problems.append(
                "%s: mark %d span %d..%d holds the letter %s at offset %d"
                % (where, number, start, end,
                   code_point(_code_point_at(units, at)), at))


def coverage_problems(texts, font, problems):
    missing = {}
    for where, text in texts.items():
        for ch in text or "":
            if ord(ch) not in font.code_points:
                missing.setdefault(ord(ch), where)
    for cp in sorted(missing):
        problems.append(
            "%s is not in the font; first at %s"
            % (code_point(cp), missing[cp]))
    if missing:
        problems.append(
            "%d code points of the text are not in the font" % len(missing))
