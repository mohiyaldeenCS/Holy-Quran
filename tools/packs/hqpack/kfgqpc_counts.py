"""The independent reference of docs/CONTENT_PACKS.md, P5: ayah counts per surah of the KFGQPC Hafs file.

Derived from the KFGQPC file alone, never from a pack or a Tanzil file. It
holds the file's name, version and SHA-256, the date it was counted, the
count of each surah and the total; no text.
"""

from __future__ import annotations

import datetime
import json
import re
from collections import OrderedDict

from . import kfgqpc
from .errors import PackError

_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}\Z")


def kfgqpc_counts(path, date, profile):
    if not _DATE.match(date):
        raise PackError("the date is not YYYY-MM-DD")
    try:
        datetime.date.fromisoformat(date)
    except ValueError:
        raise PackError("the date %s is not a day of the calendar" % date) from None
    ayat, sha256 = kfgqpc.read_kfgqpc_file(path, profile.ayat)
    surahs = OrderedDict()
    for aya in ayat:
        surahs[str(aya.surah)] = surahs.get(str(aya.surah), 0) + 1
    if len(surahs) != profile.surahs:
        raise PackError("KFGQPC: the file has %d surahs, not %d" % (len(surahs), profile.surahs))
    return OrderedDict(
        [
            (
                "kfgqpc_file",
                OrderedDict(
                    [
                        ("registry_row", kfgqpc.REGISTRY_ROW),
                        ("name", kfgqpc.FILE_NAME),
                        ("version", kfgqpc.VERSION),
                        ("sha256", sha256),
                    ]
                ),
            ),
            ("date", date),
            ("surahs", surahs),
            ("total", len(ayat)),
        ]
    )


def encode_counts(counts):
    """Two-space indent, a final line break; ASCII."""
    return (json.dumps(counts, ensure_ascii=True, indent=2) + "\n").encode("ascii")
