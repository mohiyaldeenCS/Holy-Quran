"""KFGQPC's Hafs table, `hafsData_v2-0.json` of `UthmanicHafs_v2-0.zip` (registry row 2).

The published form: UTF-8 without a BOM (the file begins with `[`, a line
feed and a tab; the BOM is the CSV's, not this file's), an array of one object per ayah with
exactly the columns of the read.me, ids 1..n in order, and the ayat in mushaf
order. Anything else is refused. Errors name the entry, its id and a field,
never a value, so no text reaches a log.

`text_offsets` finds where each `aya_text` lies in the file's bytes, so that a
pack whose text is this file can be read back against them (D-198). It needs
the text written plainly; a file that writes `aya_text` or a field name with
an escape sequence is refused there, and only there: as a witness the file is
read by its parsed values.
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
# The font of the same zip, the one the KFGQPC text is drawn with (D-198 Q2).
FONT_FILE_NAME = "uthmanic_hafs_v20.ttf"

_BOM = b"\xef\xbb\xbf"
_OPENING = b"[\n\t"
_INTEGERS = ("id", "jozz", "page", "sura_no", "line_start", "line_end", "aya_no")
_STRINGS = ("sura_name_en", "sura_name_ar", "aya_text", "aya_text_emlaey")
_COLUMNS = frozenset(_INTEGERS + _STRINGS)
# A string literal in the file's bytes: neither the quote nor the backslash
# byte occurs inside a multi-byte UTF-8 sequence.
_STRING_LITERAL = re.compile(rb'"(?:[^"\\]|\\.)*"', re.DOTALL)
_FOLLOWED_BY_COLON = re.compile(rb"[ \t\n\r]*:")
_TEXT_NAME = b'"aya_text"'
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


def check_file_name(path):
    """Refuses a KFGQPC file that does not have its published name."""
    name = Path(path).name
    if name != FILE_NAME:
        name = "".join(c if " " <= c <= "~" else code_point(c) for c in name)
        raise PackError("the KFGQPC file is named %s, not %s as published" % (name, FILE_NAME))


def read_kfgqpc_file(path, ayat):
    """(the KfgqpcAya list, the file's SHA-256) of the file at `path`, which must have the published name."""
    check_file_name(path)
    data = Path(path).read_bytes()
    return read_kfgqpc(data, ayat), digest.sha256_bytes(data)


def read_kfgqpc(data: bytes, ayat: int) -> list:
    """The KfgqpcAya list of the file, which must hold exactly `ayat` entries."""
    try:
        return _read(data, ayat)
    except PackError as e:
        raise PackError("KFGQPC: %s" % e) from None


def text_offsets(data: bytes, ayat: list) -> list:
    """(offset, length) of each ayah's aya_text in `data`, the bytes `read_kfgqpc` read `ayat` from.

    Each entry writes its field names plainly, so the nth plain "aya_text"
    name is the nth entry's and the string literal after it is its text. That
    literal must hold no escape sequence, so that its bytes are the text; they
    are checked against the parsed text.
    """
    try:
        return _text_offsets(data, ayat)
    except PackError as e:
        raise PackError("KFGQPC: %s" % e) from None


def _text_offsets(data, ayat):
    offsets = []
    literals = _STRING_LITERAL.finditer(data)
    for literal in literals:
        if not _FOLLOWED_BY_COLON.match(data, literal.end()):
            continue
        if _BACKSLASH in literal.group():
            raise PackError(
                "a field name near byte %d is written with an escape sequence" % literal.start()
            )
        if literal.group() != _TEXT_NAME:
            continue
        aya = ayat[len(offsets)]
        value = next(literals)
        start, end = value.start() + 1, value.end() - 1
        if _BACKSLASH in data[start:end]:
            raise PackError(
                "id %d: field aya_text is written with an escape sequence, so its "
                "bytes in the file are not its text" % aya.id
            )
        if data[start:end].decode("utf-8") != aya.text:
            raise PackError("id %d: field aya_text in the file's bytes is not the parsed text" % aya.id)
        offsets.append((start, end - start))
    return offsets


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
    result = []
    previous = (0, 0)
    for index, entry in enumerate(entries, 1):
        aya = _entry(entry, index)
        if aya.id != index:
            raise PackError("entry %d has id %d, not %d" % (index, aya.id, index))
        address = (aya.surah, aya.number)
        if address not in ((previous[0], previous[1] + 1), (previous[0] + 1, 1)):
            raise PackError(
                "id %d is %d:%d, which does not follow %d:%d"
                % ((aya.id,) + address + previous)
            )
        previous = address
        result.append(aya)
    return result


def _entry(entry, index):
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
    return KfgqpcAya(
        id=entry["id"],
        surah=entry["sura_no"],
        number=entry["aya_no"],
        juz=entry["jozz"],
        page=entry["page"],
        text=entry["aya_text"],
        emlaey=entry["aya_text_emlaey"],
    )


def _object(pairs):
    names = [name for name, _ in pairs]
    if len(set(names)) != len(names):
        raise PackError("an object repeats a field name")
    return dict(pairs)


def _no_constant(name):
    raise PackError("the file holds %s, which is not JSON" % name)
