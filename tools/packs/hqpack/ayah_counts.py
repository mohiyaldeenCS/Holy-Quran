"""The P5 reference counts read back (docs/CONTENT_PACKS.md, P5), strictly in
the form `kfgqpc_counts.py` writes: ASCII, its keys in its order, its
indentation and final line break, the KFGQPC file it names, and a total equal
to the sum. The tafsir checks take each surah's ayah count from it.
"""

from __future__ import annotations

import datetime
import json
import re

from . import kfgqpc
from .errors import PackError
from .kfgqpc_counts import encode_counts

_HASH = re.compile(r"[0-9a-f]{64}\Z")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}\Z")
_KEYS = ["kfgqpc_file", "date", "surahs", "total"]
_FILE_KEYS = ["registry_row", "name", "version", "sha256"]


class _Duplicate(ValueError):
    pass


def read_ayah_counts(data: bytes) -> dict:
    """{surah: ayah count}, surahs 1 to n in order."""
    if not isinstance(data, bytes) or not data.isascii():
        raise PackError("ayah counts: the file is not ASCII")
    try:
        counts = json.loads(
            data.decode("ascii"),
            object_pairs_hook=_pairs,
            parse_constant=_refuse,
            parse_float=_refuse,
        )
    except _Duplicate:
        raise PackError("ayah counts: an object repeats a key") from None
    except ValueError:
        raise PackError("ayah counts: the file is not JSON of integers and strings") from None
    _check_object(counts, _KEYS, "the file")
    _check_file(counts["kfgqpc_file"])
    _check_date(counts["date"])
    surahs = _check_surahs(counts["surahs"])
    total = counts["total"]
    if type(total) is not int or total != sum(surahs.values()):
        raise PackError("ayah counts: total is not the sum of the surahs' counts")
    if encode_counts(counts) != data:
        raise PackError("ayah counts: the bytes are not as kfgqpc-counts writes them")
    return surahs


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _Duplicate()
        result[key] = value
    return result


def _refuse(_):
    raise ValueError()


def _check_object(value, keys, where):
    if not isinstance(value, dict) or list(value) != keys:
        raise PackError("ayah counts: %s is not an object of %s in that order" % (where, ", ".join(keys)))


def _check_file(file):
    _check_object(file, _FILE_KEYS, "kfgqpc_file")
    expected = (kfgqpc.REGISTRY_ROW, kfgqpc.FILE_NAME, kfgqpc.VERSION)
    if (file["registry_row"], file["name"], file["version"]) != expected or type(file["registry_row"]) is not int:
        raise PackError("ayah counts: kfgqpc_file is not registry row %d, %s" % (kfgqpc.REGISTRY_ROW, kfgqpc.FILE_NAME))
    if not isinstance(file["sha256"], str) or not _HASH.match(file["sha256"]):
        raise PackError("ayah counts: kfgqpc_file.sha256 is not lowercase hex SHA-256")


def _check_date(date):
    if not isinstance(date, str) or not _DATE.match(date):
        raise PackError("ayah counts: date is not YYYY-MM-DD")
    try:
        datetime.date.fromisoformat(date)
    except ValueError:
        raise PackError("ayah counts: date is not a day of the calendar") from None


def _check_surahs(surahs):
    if not isinstance(surahs, dict) or not surahs:
        raise PackError("ayah counts: surahs is not a non-empty object")
    result = {}
    for index, (key, count) in enumerate(surahs.items(), 1):
        if key != str(index):
            raise PackError("ayah counts: surahs key %d is not %d" % (index, index))
        if type(count) is not int or count < 1:
            raise PackError("ayah counts: surah %d's count is not a positive integer" % index)
        result[index] = count
    return result
