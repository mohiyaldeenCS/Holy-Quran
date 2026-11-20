"""Word and mark spans and font coverage, recomputed from the stored text
by the D-083 rule, for the independent verifier.

A pack of format 3 stores its text with its presentation (D-198 Q4). The
ayah-end separator and number glyph, and the quarter sign and separator that
open a quarter, are rows of the presentation table, recomputed here from the
table's presentation rules; a separator other than U+0020 may stand there and
nowhere else. And a run of the D-078 marks that ends a token holding a letter
is a mark of its own, cut from its word at its offset.
"""

from __future__ import annotations

import struct
import unicodedata

from .errors import code_point

_SEPARATORS = ("Zs", "Zl", "Zp", "Cc")
# This verifier's own copy of the marks a KFGQPC text joins to the word
# before them: the pause marks U+06D6 to U+06DB and the sajda sign.
_JOINED = frozenset(range(0x06D6, 0x06DC)) | {0x06E9}


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


def _positions(text):
    """The UTF-16 offset of every code point index of `text`, and of its end."""
    positions = [0]
    for ch in text:
        positions.append(positions[-1] + (2 if ord(ch) > 0xFFFF else 1))
    return positions


def _presented(where, text, presentation, address, problems):
    """(tokens, presentation rows) of a text stored with its presentation:
    the opening and ending cut by the rules, then the runs between U+0020
    of the rest, a run of joined marks that ends a word a token of its own."""
    separator = presentation.ayah_end_separators.get(
        address, presentation.ayah_end_separator)
    ending = chr(separator) + chr(
        presentation.first_number_glyph + address[1] - 1)
    opening = chr(presentation.quarter_sign) + chr(
        presentation.quarter_separator)
    positions = _positions(text)
    start = len(opening) if text.startswith(opening) else 0
    end = len(text)
    if text.endswith(ending) and end - len(ending) > start:
        end -= len(ending)
    else:
        problems.append(
            "%s does not end with %s %s, its ayah-end presentation"
            % (where, code_point(ending[0]), code_point(ending[1])))
    tokens = _body_tokens(text, start, end, positions)
    words = sum(1 for token in tokens if token[2])
    shown = []
    if start:
        shown.append((1, 0, 0, positions[start]))
    if end < len(text):
        shown.append((len(shown) + 1, words, positions[end], positions[-1]))
    return tokens, shown


def _body_tokens(text, start, end, positions):
    tokens = []
    index = start
    while index < end:
        if text[index] == " ":
            index += 1
            continue
        stop = index
        while stop < end and text[stop] != " ":
            stop += 1
        points = [ord(ch) for ch in text[index:stop]]
        if any(map(_is_letter, points)):
            cut = len(points)
            while points[cut - 1] in _JOINED:
                cut -= 1
            tokens.append(
                (positions[index], positions[index + cut], True, points[:cut]))
            if cut < len(points):
                tokens.append((positions[index + cut], positions[stop], False,
                               points[cut:]))
        else:
            tokens.append((positions[index], positions[stop], False, points))
        index = stop
    return tokens


def all_span_problems(pack, texts, mark_code_points, problems,
                      presentation=None):
    """`presentation`, the rules of known_differences.Presentation, for a
    pack of format 3; None for format 1, which has no presentation rows."""
    outside = {}
    presented = presentation is not None
    for surah, number, _ in pack.ayat:
        where = "ayah %d:%d" % (surah, number)
        text = texts.get(where)
        if text is None:
            continue
        words = pack.words.get((surah, number), [])
        marks = pack.marks.get((surah, number), [])
        shown = pack.presentation.get((surah, number), [])
        units = _code_units(text)
        if presented:
            tokens, expected_shown = _presented(
                where, text, presentation, (surah, number), problems)
            _quarter_sign_problems(
                where, text, presentation.quarter_sign, expected_shown,
                problems)
        else:
            tokens, expected_shown = _tokens(text), []
        _separator_problems(where, text, expected_shown, problems)
        _recomputed_problems(where, tokens, words, marks, problems)
        _row_differences(where, "presentation", shown, expected_shown,
                         problems)
        _order_problems(where, units, words, marks, shown, problems)
        _token_problems(where, units, words, marks, shown, presented,
                        problems)
        _gap_problems(where, units, words, marks, shown, problems)
        _letter_problems(where, units, words, marks, presented, problems)
        if mark_code_points is not None:
            for _, _, is_word, points in tokens:
                for cp in points:
                    if not is_word and cp not in mark_code_points:
                        outside.setdefault(cp, where)
    for cp in sorted(outside):
        problems.append(
            "%s is in a mark but not in the mark table; first at %s"
            % (code_point(cp), outside[cp]))


def _inside(rows, offset):
    return any(row[-2] <= offset < row[-1] for row in rows)


def _separator_problems(where, text, shown, problems):
    """A separator inside a presentation row of `shown` is the presentation's own."""
    offset = 0
    for ch in text:
        if (ch != " " and unicodedata.category(ch) in _SEPARATORS
                and not _inside(shown, offset)):
            problems.append(
                "%s: %s at offset %d is a separator other than U+0020"
                % (where, code_point(ch), offset))
        offset += 2 if ord(ch) > 0xFFFF else 1


def _quarter_sign_problems(where, text, sign, shown, problems):
    offset = 0
    for ch in text:
        if ord(ch) == sign and not _inside(shown, offset):
            problems.append(
                "%s: %s at offset %d lies outside the presentation that opens "
                "a quarter" % (where, code_point(sign), offset))
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
    if kind != "word":
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


def _spans(words, marks, shown=()):
    """(kind, number, start, end) of every stored span."""
    return ([("word", n, s, e) for n, s, e in words]
            + [("mark", n, s, e) for n, _, s, e in marks]
            + [("presentation", n, s, e) for n, _, s, e in shown])


def _in_bounds(units, start, end):
    return 0 <= start < end <= len(units)


def _splits_pair(units, offset):
    return (0 < offset < len(units)
            and 0xD800 <= units[offset - 1] < 0xDC00
            and 0xDC00 <= units[offset] < 0xE000)


def _order_problems(where, units, words, marks, shown, problems):
    """Numbering, order, bounds, surrogate pairs and after_word, walking the
    stored words, marks and presentation spans together in text order."""
    lists = (("word", words), ("mark", marks), ("presentation", shown))
    for kind, rows in lists:
        for index, row in enumerate(rows):
            if row[0] != index + 1:
                problems.append(
                    "%s: %s %d is numbered %d" % (where, kind, index + 1,
                                                 row[0]))
    taken = [0, 0, 0]
    previous_end = 0
    while True:
        heads = [(rows[taken[k]][-2], k) for k, (_, rows) in enumerate(lists)
                 if taken[k] < len(rows)]
        if not heads:
            break
        k = min(heads)[1]
        kind, rows = lists[k]
        row = rows[taken[k]]
        taken[k] += 1
        number, start, end = row[0], row[-2], row[-1]
        if kind != "word" and row[1] != taken[0]:
            problems.append(
                "%s: %s %d has after_word %d; %d words come before it"
                % (where, kind, number, row[1], taken[0]))
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


def _token_problems(where, units, words, marks, shown, presented, problems):
    """A word or mark span is a token, or in format 3 meets the span it is
    cut from: a joined mark its word, the text its presentation."""
    spans = _spans(words, marks, shown)
    starts = {start for _, _, start, _ in spans} if presented else set()
    ends = {end for _, _, _, end in spans} if presented else set()
    for kind, number, start, end in _spans(words, marks):
        if not _in_bounds(units, start, end):
            continue
        name = "%s: %s %d span %d..%d" % (where, kind, number, start, end)
        if 0x20 in units[start:end]:
            problems.append("%s holds U+0020" % name)
        if start > 0 and units[start - 1] != 0x20 and start not in ends:
            problems.append("%s does not start a token" % name)
        if end < len(units) and units[end] != 0x20 and end not in starts:
            problems.append("%s does not end a token" % name)


def _gap_problems(where, units, words, marks, shown, problems):
    covered = [False] * len(units)
    for _, _, start, end in _spans(words, marks, shown):
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


def _letter_problems(where, units, words, marks, presented, problems):
    for number, start, end in words:
        if not _in_bounds(units, start, end):
            continue
        if _first_letter(units, start, end) is None:
            problems.append(
                "%s: word %d span %d..%d holds no letter"
                % (where, number, start, end))
        joined = [cp for cp in units[start:end] if cp in _JOINED]
        if presented and joined:
            problems.append(
                "%s: word %d span %d..%d holds the mark %s"
                % (where, number, start, end, code_point(joined[0])))
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
