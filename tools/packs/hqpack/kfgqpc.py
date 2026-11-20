"""KFGQPC's Hafs table, `hafsData_v2-0.json` of `UthmanicHafs_v2-0.zip` (registry row 2).

The published form: UTF-8 without a BOM (the file begins with `[`, a line
feed and a tab; the BOM is the CSV's, not this file's), an array of one object per ayah with
exactly the columns of the read.me, ids 1..n in order, and the ayat in mushaf
order. Anything else is refused. Errors name the entry, its id and a field,
never a value, so no text reaches a log.

Each ayah keeps where its `aya_text` lies in the file's bytes, so that a pack
built from the file can be read back against them. That needs the text written
plainly: an escape sequence inside `aya_text`, or in a field name, is refused.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

from . import digest
from .errors import PackError, code_point

FILE_NAME = "hafsData_v2-0.json"
VERSION = "2.0 (update 13.0)"
REGISTRY_ROW = 2

_BOM = b"\xef\xbb\xbf"
_OPENING = b"[\n\t"
_INTEGERS = ("id", "jozz", "page", "sura_no", "line_start", "line_end", "aya_no")
_STRINGS = ("sura_name_en", "sura_name_ar", "aya_text", "aya_text_emlaey")
_COLUMNS = frozenset(_INTEGERS + _STRINGS)
# A string literal in the file's bytes: neither the quote nor the backslash
# byte occurs inside a multi-byte UTF-8 sequence.
_STRING_LITERAL = re.compile(rb'"(?:[^"\\]|\\.)*"', re.DOTALL)
_FOLLOWED_BY_COLON = re.compile(rb"[ \t\n\r]*:")
_TEXT_KEY = b'"aya_text"'
_BACKSLASH = b"\\"


@dataclass(frozen=True)
class KfgqpcAya:
    id: int
    surah: int
    number: int
    juz: int
    page: int
    text: str
    emlaey: str
    text_offset: int  # where aya_text's bytes begin in the file, after its opening quote
    text_length: int  # how many bytes it has


def read_kfgqpc_file(path, ayat):
    """(the KfgqpcAya list, the file's SHA-256) of the file at `path`, which must have the published name."""
    path = Path(path)
    if path.name != FILE_NAME:
        name = "".join(c if " " <= c <= "~" else code_point(c) for c in path.name)
        raise PackError("the KFGQPC file is named %s, not %s as published" % (name, FILE_NAME))
    data = path.read_bytes()
    return read_kfgqpc(data, ayat), digest.sha256_bytes(data)


def read_kfgqpc(data: bytes, ayat: int) -> list:
    """The KfgqpcAya list of the file, which must hold exactly `ayat` entries."""
    try:
        return _read(data, ayat)
    except PackError as e:
        raise PackError("KFGQPC: %s" % e) from None


def _read(data, ayat):
    if data.startswith(_BOM):
        raise PackError("the file begins with a UTF-8 BOM, which the published file does not")
    if not data.startswith(_OPENING):
        raise PackError("the file does not begin with '[', a line feed and a tab (5B 0A 09), as the published file does")
    try:
        document = data.decode("utf-8")
    except UnicodeDecodeError as e:
        raise PackError("malformed UTF-8 at byte %d" % e.start) from None
    try:
        entries = json.loads(
            document, object_pairs_hook=_object, parse_constant=_no_constant
        )
    except json.JSONDecodeError as e:
        raise PackError("invalid JSON at line %d column %d" % (e.lineno, e.colno)) from None
    # The opening bytes make the top level an array.
    if len(entries) != ayat:
        raise PackError("the file holds %d entries, not %d" % (len(entries), ayat))
    previous = (0, 0)
    for index, entry in enumerate(entries, 1):
        _check_entry(entry, index)
        if entry["id"] != index:
            raise PackError("entry %d has id %d, not %d" % (index, entry["id"], index))
        address = (entry["sura_no"], entry["aya_no"])
        if address not in ((previous[0], previous[1] + 1), (previous[0] + 1, 1)):
            raise PackError(
                "id %d is %d:%d, which does not follow %d:%d"
                % ((entry["id"],) + address + previous)
            )
        previous = address
    return [_aya(entry, span) for entry, span in zip(entries, _text_spans(data, entries))]


def _text_spans(data, entries):
    """(offset, length) of every entry's aya_text in `data`, in entry order.

    `entries` are the parsed objects, already checked, in the order of the
    file. Every field name is written plainly, so the nth plain `"aya_text"`
    name is the nth entry's, and the string literal after it is its value.
    """
    spans = []
    literals = _STRING_LITERAL.finditer(data)
    for literal in literals:
        if not _is_name(data, literal.end()):
            continue
        if _BACKSLASH in literal.group():
            raise PackError(
                "a field name near byte %d is written with an escape sequence" % literal.start()
            )
        if literal.group() != _TEXT_KEY:
            continue
        value = next(literals)
        entry = entries[len(spans)]
        start, end = value.start() + 1, value.end() - 1
        raw = data[start:end]
        if _BACKSLASH in raw:
            raise PackError(
                "id %d: field aya_text is written with an escape sequence, so its "
                "bytes in the file are not its text" % entry["id"]
            )
        if raw.decode("utf-8") != entry["aya_text"]:
            raise PackError(
                "id %d: field aya_text in the file's bytes is not the parsed text" % entry["id"]
            )
        spans.append((start, end - start))
    return spans


def _is_name(data, end):
    """Whether the string literal ending at `end` is a field name: a colon follows it."""
    return _FOLLOWED_BY_COLON.match(data, end) is not None


def _check_entry(entry, index):
    if not isinstance(entry, dict):
        raise PackError("entry %d is not an object" % index)
    label = "entry %d" % index
    if type(entry.get("id")) is int:
        label = "id %d" % entry["id"]
    for column in sorted(_COLUMNS):
        if column not in entry:
            raise PackError("%s lacks field %s" % (label, column))
    if len(entry) != len(_COLUMNS):
        raise PackError("%s has a field other than the columns of the read.me" % label)
    for column in _INTEGERS:
        value = entry[column]
        if type(value) is not int:
            raise PackError("%s: field %s is not an integer" % (label, column))
        if value < 1:
            raise PackError("%s: field %s is %d, below 1" % (label, column, value))
    for column in _STRINGS:
        value = entry[column]
        if type(value) is not str:
            raise PackError("%s: field %s is not a string" % (label, column))
        try:
            value.encode("utf-8")
        except UnicodeEncodeError as e:
            raise PackError(
                "%s: field %s holds a lone surrogate at index %d" % (label, column, e.start)
            ) from None
    if not entry["aya_text"]:
        raise PackError("%s: field aya_text is empty" % label)


def _aya(entry, span):
    return KfgqpcAya(
        id=entry["id"],
        surah=entry["sura_no"],
        number=entry["aya_no"],
        juz=entry["jozz"],
        page=entry["page"],
        text=entry["aya_text"],
        emlaey=entry["aya_text_emlaey"],
        text_offset=span[0],
        text_length=span[1],
    )


def _object(pairs):
    names = [name for name, _ in pairs]
    if len(set(names)) != len(names):
        raise PackError("an object repeats a field name")
    return dict(pairs)


def _no_constant(name):
    raise PackError("the file holds %s, which is not JSON" % name)
