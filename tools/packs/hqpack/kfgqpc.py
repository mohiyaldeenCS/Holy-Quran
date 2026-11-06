"""KFGQPC's Hafs table, `hafsData_v2-0.json` of `UthmanicHafs_v2-0.zip` (registry row 2).

The published form: UTF-8 without a BOM (the file begins with `[`, a line
feed and a tab; the BOM is the CSV's, not this file's), an array of one object per ayah with
exactly the columns of the read.me, ids 1..n in order, and the ayat in mushaf
order. Anything else is refused. Errors name the entry, its id and a field,
never a value, so no text reaches a log.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from . import digest
from .errors import PackError, code_point

FILE_NAME = "hafsData_v2-0.json"
VERSION = "2.0 (update 13.0)"
REGISTRY_ROW = 2

_BOM = b"\xef\xbb\xbf"
_INTEGERS = ("id", "jozz", "page", "sura_no", "line_start", "line_end", "aya_no")
_STRINGS = ("sura_name_en", "sura_name_ar", "aya_text", "aya_text_emlaey")
_COLUMNS = frozenset(_INTEGERS + _STRINGS)


@dataclass(frozen=True)
class KfgqpcAya:
    id: int
    surah: int
    number: int
    juz: int
    page: int
    text: str


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
    if not isinstance(entries, list):
        raise PackError("the top level is not an array")
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
    )


def _object(pairs):
    names = [name for name, _ in pairs]
    if len(set(names)) != len(names):
        raise PackError("an object repeats a field name")
    return dict(pairs)


def _no_constant(name):
    raise PackError("the file holds %s, which is not JSON" % name)
