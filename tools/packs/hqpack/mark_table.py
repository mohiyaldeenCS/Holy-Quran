"""The mark table: the code points a letterless token may hold (D-078).

The file is strict UTF-8 JSON without a BOM: `{"code_points": ["U+06D6", ...]}`,
strictly ascending, none a letter, a separator or a control character.
"""

from __future__ import annotations

import json
import re
import unicodedata

from .errors import PackError, code_point
from .tokens import is_letter

_ENTRY = re.compile(r"U\+[0-9A-F]{4,6}")
_KEY = "code_points"


def read_mark_table(data: bytes) -> frozenset:
    code_points = []
    for index, entry in enumerate(_entries(_load(data))):
        cp = _parse_entry(index, entry)
        if code_points and cp <= code_points[-1]:
            raise PackError(
                "mark table entry %d (%s) is not after %s; the list must be "
                "strictly ascending"
                % (index, code_point(cp), code_point(code_points[-1]))
            )
        _check_allowed(index, cp)
        code_points.append(cp)
    return frozenset(code_points)


def _load(data: bytes):
    if data.startswith(b"\xef\xbb\xbf"):
        raise PackError("the mark table starts with a byte order mark")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PackError(
            "the mark table is not UTF-8 at byte %d" % error.start
        ) from None
    try:
        return json.loads(text, object_pairs_hook=_unique_keys)
    except json.JSONDecodeError as error:
        raise PackError(
            "the mark table is not JSON at line %d column %d"
            % (error.lineno, error.colno)
        ) from None


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PackError("the mark table repeats a key")
        result[key] = value
    return result


def _entries(document) -> list:
    if not isinstance(document, dict) or list(document) != [_KEY]:
        raise PackError(
            'the mark table must be an object with the one key "code_points"'
        )
    entries = document[_KEY]
    if not isinstance(entries, list) or not entries:
        raise PackError("code_points of the mark table must be a non-empty list")
    return entries


def _parse_entry(index: int, entry) -> int:
    if not isinstance(entry, str) or not _ENTRY.fullmatch(entry):
        raise PackError(
            "mark table entry %d is not U+ and four to six upper-case hex digits"
            % index
        )
    cp = int(entry[2:], 16)
    if cp > 0x10FFFF:
        raise PackError("mark table entry %d is beyond U+10FFFF" % index)
    if code_point(cp) != entry:
        raise PackError(
            "mark table entry %d must be written %s" % (index, code_point(cp))
        )
    return cp


def _check_allowed(index: int, cp: int) -> None:
    category = unicodedata.category(chr(cp))
    if category == "Cs":
        raise PackError(
            "mark table entry %d (%s) is a surrogate" % (index, code_point(cp))
        )
    if is_letter(cp):
        raise PackError(
            "mark table entry %d (%s) is a letter" % (index, code_point(cp))
        )
    if category.startswith("Z") or category == "Cc":
        raise PackError(
            "mark table entry %d (%s) is of category %s"
            % (index, code_point(cp), category)
        )
