"""`manifest.json` of format v1: its fields in the format's order, and its bytes.

docs/CONTENT_PACKS.md, "Manifest". Errors name field paths only, never a
value.
"""

from __future__ import annotations

import json

from .errors import PackError

_SOURCE_KEYS = (
    "role",
    "registry_row",
    "name",
    "publisher",
    "url",
    "version",
    "fetched_on",
    "file_sha256",
    "trust_grade",
    "options",
    "licence",
)
_LICENCE_KEYS = ("text", "permission_ref", "notice", "allows_export")
_FONT_KEYS = ("family", "version", "sha256")
_CHANGE_KEYS = ("version", "date", "summary")
_REVIEW_KEYS = ("reviewer", "date", "scope")
_COUNT_KEYS = ("surahs", "ayat", "words", "marks", "divisions", "sajdas")
_DIVISION_KEYS = ("juz", "hizb", "rub", "page")


def source_entry(
    *,
    role,
    registry_row,
    name,
    publisher,
    url,
    version,
    fetched_on,
    file_sha256,
    trust_grade,
    options,
    licence,
) -> dict:
    if options is not None:
        if not isinstance(options, dict) or not options:
            raise PackError("manifest: source options is empty or not an object; use null")
        if "" in options:
            raise PackError("manifest: source options has an empty option name")
        options = dict(options)
    licence = _ordered(licence, _LICENCE_KEYS, "source licence")
    if licence["text"] is None and licence["permission_ref"] is None:
        raise PackError("manifest: source licence has neither text nor permission_ref")
    return {
        "role": role,
        "registry_row": registry_row,
        "name": name,
        "publisher": publisher,
        "url": url,
        "version": version,
        "fetched_on": fetched_on,
        "file_sha256": file_sha256,
        "trust_grade": trust_grade,
        "options": options,
        "licence": licence,
    }


def build_manifest(
    *,
    pack_id,
    version,
    changelog,
    riwaya,
    edition,
    font,
    sources,
    text_sha256,
    text_bytes,
    surah_sha256,
    counts,
    reviews,
) -> dict:
    counts = _ordered(counts, _COUNT_KEYS, "counts")
    counts["divisions"] = _ordered(counts["divisions"], _DIVISION_KEYS, "counts.divisions")
    return {
        "format": "holyquran-pack",
        "format_version": 1,
        "id": pack_id,
        "kind": "text",
        "version": version,
        "changelog": _ordered_list(changelog, _CHANGE_KEYS, "changelog"),
        "riwaya": riwaya,
        "edition": edition,
        "font": _ordered(font, _FONT_KEYS, "font"),
        "sources": [_source(s, "sources[%d]" % i) for i, s in enumerate(sources)],
        "files": [{"name": "text.sqlite", "sha256": text_sha256, "bytes": text_bytes}],
        "surah_sha256": _surah_digests(surah_sha256, counts["surahs"]),
        "counts": counts,
        "reviews": _ordered_list(reviews, _REVIEW_KEYS, "reviews"),
    }


def encode_manifest(manifest: dict) -> bytes:
    """UTF-8 without BOM, two-space indent, non-ASCII unescaped, final line break."""
    _check_value(manifest, "manifest")
    try:
        text = json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False)
        return (text + "\n").encode("utf-8", "strict")
    except (TypeError, ValueError) as e:
        raise PackError("manifest: encoding failed (%s)" % type(e).__name__) from None


def _source(source, where: str) -> dict:
    source = _ordered(source, _SOURCE_KEYS, where)
    source["licence"] = _ordered(source["licence"], _LICENCE_KEYS, where + ".licence")
    return source


def _ordered(obj, keys, where: str) -> dict:
    if not isinstance(obj, dict):
        raise PackError("manifest: %s is not an object" % where)
    for key in keys:
        if key not in obj:
            raise PackError("manifest: %s lacks field %s" % (where, key))
    if len(obj) != len(keys):
        raise PackError("manifest: %s has an unknown field" % where)
    return {key: obj[key] for key in keys}


def _ordered_list(items, keys, where: str) -> list:
    return [_ordered(item, keys, "%s[%d]" % (where, i)) for i, item in enumerate(items)]


def _surah_digests(digests, surahs) -> dict:
    by_number = {}
    for key, value in digests.items():
        number = _surah_number(key)
        if number is None or number in by_number:
            raise PackError("manifest: surah_sha256 has a key that is not a surah number")
        by_number[number] = value
    if sorted(by_number) != list(range(1, surahs + 1)):
        raise PackError("manifest: surah_sha256 does not hold exactly surahs 1 to %s" % surahs)
    return {str(n): by_number[n] for n in sorted(by_number)}


def _surah_number(key):
    """`key` as an int when it is one, or the decimal string of one."""
    if isinstance(key, bool):
        return None
    if isinstance(key, int):
        return key
    if isinstance(key, str) and key.isascii() and key.isdigit() and str(int(key)) == key:
        return int(key)
    return None


def _check_value(value, where: str) -> None:
    if isinstance(value, dict):
        for index, (key, item) in enumerate(value.items()):
            if not isinstance(key, str):
                raise PackError("manifest: %s has a key that is not a string" % where)
            name = key if key.isascii() and key.isprintable() else "<key %d>" % index
            _check_string(key, "a key of " + where)
            _check_value(item, "%s.%s" % (where, name))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            _check_value(item, "%s[%d]" % (where, index))
    elif isinstance(value, str):
        _check_string(value, where)
    elif isinstance(value, float):
        raise PackError("manifest: %s is a float" % where)
    elif value is not None and not isinstance(value, int):
        raise PackError("manifest: %s is not a JSON value" % where)


def _check_string(value: str, where: str) -> None:
    if value.startswith("\ufeff"):
        raise PackError("manifest: %s begins with U+FEFF" % where)
    try:
        value.encode("utf-8", "strict")
    except UnicodeEncodeError as e:
        raise PackError(
            "manifest: %s holds a lone surrogate at index %d" % (where, e.start)
        ) from None
