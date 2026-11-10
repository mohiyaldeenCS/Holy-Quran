"""The description of a tafsir pack built from a Zaydi-library book
(docs/plans/B07_TAFSIR_PACK.md, "CLI").

Strict UTF-8 JSON without a BOM; every key is required and no other is
allowed. The source's registry row, url and version are not in it: they
follow from D-187 and the book's `meta.json`. Messages name JSON paths only.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path

from . import strict_json as sj
from .config import _changelog, _licence, _reviews
from .errors import PackError

RIWAYA = "hafs"  # the P5 counts are KFGQPC Hafs's, the only ones there are

_PACK_ID = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
_KEYS = (
    "id", "version", "changelog", "riwaya", "book", "extraction", "links",
    "pages_sha256", "passages_sha256", "source", "reviews",
)
_SOURCE_KEYS = ("name", "publisher", "fetched_on", "trust_grade", "licence")
_TRUST_GRADES = ("A", "B", "C")


@dataclass(frozen=True)
class TafsirConfig:
    path: Path
    pack_id: str
    version: int
    changelog: list
    riwaya: str
    book: int
    extraction: Path  # the folder holding book_<N>/ of ziydia_fetch.py
    links: Path  # the folder holding book_<N>/ of ziydia_link.py
    pages_sha256: str
    passages_sha256: str
    source: dict  # name, publisher, fetched_on, trust_grade, licence
    reviews: list


def read_tafsir_config(path) -> TafsirConfig:
    path = Path(os.path.abspath(path))
    try:
        data = path.read_bytes()
    except OSError:
        raise PackError("tafsir description: the file cannot be read") from None
    try:
        return _config(path, sj.load(data))
    except PackError as error:
        raise PackError("tafsir description: %s" % error) from None


def _config(path, document):
    sj.fields(document, _KEYS, "the description")
    pack_id = document["id"]
    if not isinstance(pack_id, str) or not _PACK_ID.fullmatch(pack_id):
        raise PackError("id must match %s" % _PACK_ID.pattern)
    if document["riwaya"] != RIWAYA:
        raise PackError("riwaya must be %s: the only ayah counts (P5) are KFGQPC Hafs's" % RIWAYA)
    version = sj.positive_int(document["version"], "version")
    return TafsirConfig(
        path=path,
        pack_id=pack_id,
        version=version,
        changelog=_changelog(document["changelog"], version),
        riwaya=RIWAYA,
        book=sj.positive_int(document["book"], "book"),
        extraction=_folder(document["extraction"], "extraction", path.parent),
        links=_folder(document["links"], "links", path.parent),
        pages_sha256=sj.sha256(document["pages_sha256"], "pages_sha256"),
        passages_sha256=sj.sha256(document["passages_sha256"], "passages_sha256"),
        source=_source(document["source"]),
        reviews=_reviews(document["reviews"]),
    )


def _source(value):
    sj.fields(value, _SOURCE_KEYS, "source")
    if value["trust_grade"] not in _TRUST_GRADES:
        raise PackError("source.trust_grade must be A, B or C")
    return {
        "name": sj.string(value["name"], "source.name"),
        "publisher": sj.string(value["publisher"], "source.publisher"),
        "fetched_on": sj.date(value["fetched_on"], "source.fetched_on"),
        "trust_grade": value["trust_grade"],
        "licence": _licence(value["licence"], "source.licence"),
    }


def _folder(value, where, base):
    """Absolute, or relative to the description's folder."""
    value = sj.string(value, where)
    return Path(os.path.abspath(base / value))
