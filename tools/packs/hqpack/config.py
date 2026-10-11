"""The build description: what a pack is, which source files it is built from
and what is known of them before they are opened.

Strict UTF-8 JSON without a BOM. Every key is required and no other key is
allowed, at every level. A message names the JSON path of the field, never its
value.
"""

from __future__ import annotations

import datetime
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path, PureWindowsPath

from .errors import PackError

_PACK_ID = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
_RIWAYA = re.compile(r"[a-z][a-z0-9_]*")
_SHA256 = re.compile(r"[0-9a-f]{64}")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
_NAMEABLE_KEY = re.compile(r"[A-Za-z0-9_]{1,64}")
_TRUST_GRADES = ("A", "B", "C")
_ROLES = ("text", "edition_map")

_TOP_KEYS = (
    "id", "version", "changelog", "riwaya", "edition", "sources", "mark_table",
    "reviews",
)
_SOURCE_KEYS = (
    "file", "file_sha256", "registry_row", "name", "publisher", "url", "version",
    "fetched_on", "trust_grade", "licence",
)
_LICENCE_KEYS = ("text", "permission_ref", "allows_export")
_CHANGELOG_KEYS = ("version", "date", "summary")
_REVIEW_KEYS = ("reviewer", "date", "scope")


@dataclass(frozen=True)
class SourceConfig:
    role: str
    file: Path
    file_sha256: str
    registry_row: int
    name: str
    publisher: str
    url: str
    version: str
    fetched_on: str
    trust_grade: str
    licence: dict


@dataclass(frozen=True)
class BuildConfig:
    path: Path
    pack_id: str
    version: int
    changelog: list
    riwaya: str
    edition: str
    text: SourceConfig
    edition_map: SourceConfig
    mark_table: Path
    reviews: list


def read_build_config(path) -> BuildConfig:
    """Reads and checks the build description, refusing it with a PackError."""
    path = Path(os.path.abspath(path))
    try:
        data = path.read_bytes()
    except OSError:
        raise PackError("build description: the file cannot be read") from None
    try:
        return _config(path, _load(data))
    except PackError as error:
        raise PackError("build description: %s" % error) from None


def _load(data: bytes):
    if data.startswith(b"\xef\xbb\xbf"):
        raise PackError("the file starts with a byte order mark")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PackError("not UTF-8 at byte %d" % error.start) from None
    try:
        return json.loads(
            text, object_pairs_hook=_unique_keys, parse_constant=_refuse_constant
        )
    except json.JSONDecodeError as error:
        raise PackError(
            "not JSON at line %d column %d" % (error.lineno, error.colno)
        ) from None


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PackError("a repeated key %s" % _key_name(key))
        result[key] = value
    return result


def _refuse_constant(name):
    raise PackError("%s is not a JSON number" % name)


def _config(path: Path, document) -> BuildConfig:
    _object(document, _TOP_KEYS, "")
    version = _positive_int(document["version"], "version")
    sources = document["sources"]
    _object(sources, _ROLES, "sources")
    return BuildConfig(
        path=path,
        pack_id=_matching(document["id"], _PACK_ID, "id"),
        version=version,
        changelog=_changelog(document["changelog"], version),
        riwaya=_matching(document["riwaya"], _RIWAYA, "riwaya"),
        edition=_string(document["edition"], "edition"),
        text=_source(sources["text"], "text", path.parent),
        edition_map=_source(sources["edition_map"], "edition_map", path.parent),
        mark_table=_relative_path(document["mark_table"], "mark_table", path.parent),
        reviews=_reviews(document["reviews"]),
    )


def _changelog(value, version: int) -> list:
    if not isinstance(value, list) or not value:
        raise PackError("changelog must be a non-empty list")
    entries = []
    for index, entry in enumerate(value):
        where = "changelog[%d]" % index
        _object(entry, _CHANGELOG_KEYS, where)
        entries.append(
            {
                "version": _positive_int(entry["version"], where + ".version"),
                "date": _date(entry["date"], where + ".date"),
                "summary": _string(entry["summary"], where + ".summary"),
            }
        )
    if not any(entry["version"] == version for entry in entries):
        raise PackError("changelog has no entry for version %d" % version)
    return entries


def _reviews(value) -> list:
    if not isinstance(value, list):
        raise PackError("reviews must be a list")
    reviews = []
    for index, entry in enumerate(value):
        where = "reviews[%d]" % index
        _object(entry, _REVIEW_KEYS, where)
        reviews.append(
            {
                "reviewer": _string(entry["reviewer"], where + ".reviewer"),
                "date": _date(entry["date"], where + ".date"),
                "scope": _string(entry["scope"], where + ".scope"),
            }
        )
    return reviews


def _source(value, role: str, base: Path) -> SourceConfig:
    where = "sources." + role
    _object(value, _SOURCE_KEYS, where)
    url = _string(value["url"], where + ".url")
    if not url.startswith("https://") or url == "https://":
        raise PackError("%s.url must be an https:// address" % where)
    trust_grade = value["trust_grade"]
    if trust_grade not in _TRUST_GRADES:
        raise PackError("%s.trust_grade must be A, B or C" % where)
    return SourceConfig(
        role=role,
        file=_relative_path(value["file"], where + ".file", base),
        file_sha256=_matching(value["file_sha256"], _SHA256, where + ".file_sha256"),
        registry_row=_positive_int(value["registry_row"], where + ".registry_row"),
        name=_string(value["name"], where + ".name"),
        publisher=_string(value["publisher"], where + ".publisher"),
        url=url,
        version=_string(value["version"], where + ".version"),
        fetched_on=_date(value["fetched_on"], where + ".fetched_on"),
        trust_grade=trust_grade,
        licence=_licence(value["licence"], where + ".licence"),
    )


def _licence(value, where: str) -> dict:
    if isinstance(value, dict) and "notice" in value:
        raise PackError(
            "%s.notice is refused: the notice is taken verbatim from the source "
            "file" % where
        )
    _object(value, _LICENCE_KEYS, where)
    licence = {
        key: _optional_string(value[key], "%s.%s" % (where, key))
        for key in ("text", "permission_ref")
    }
    if licence["text"] is None and licence["permission_ref"] is None:
        raise PackError("%s needs a text or a permission_ref" % where)
    if not isinstance(value["allows_export"], bool):
        raise PackError("%s.allows_export must be true or false" % where)
    licence["allows_export"] = value["allows_export"]
    return licence


def _object(value, keys, where: str) -> None:
    label = where or "the description"
    if not isinstance(value, dict):
        raise PackError("%s must be an object" % label)
    for key in value:
        if key not in keys:
            raise PackError("%s has an unknown key %s" % (label, _path(where, key)))
    for key in keys:
        if key not in value:
            raise PackError("%s is missing" % _path(where, key))


def _path(where: str, key) -> str:
    name = _key_name(key)
    return "%s.%s" % (where, name) if where else name


def _key_name(key: str) -> str:
    return key if _NAMEABLE_KEY.fullmatch(key) else "(a key that is not plain ASCII)"


def _string(value, where: str) -> str:
    if not isinstance(value, str) or not value:
        raise PackError("%s must be a non-empty string" % where)
    if value.startswith("\ufeff"):
        raise PackError("%s begins with U+FEFF" % where)
    return value


def _optional_string(value, where: str):
    return None if value is None else _string(value, where)


def _matching(value, pattern, where: str) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise PackError("%s must match %s" % (where, pattern.pattern))
    return value


def _positive_int(value, where: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise PackError("%s must be a positive integer" % where)
    return value


def _date(value, where: str) -> str:
    if isinstance(value, str) and _DATE.fullmatch(value):
        try:
            datetime.date.fromisoformat(value)
            return value
        except ValueError:
            pass
    raise PackError("%s must be a real date written YYYY-MM-DD" % where)


def _relative_path(value, where: str, base: Path) -> Path:
    value = _string(value, where)
    if (
        value.startswith(("/", "\\"))
        or PureWindowsPath(value).drive
        or Path(value).is_absolute()
    ):
        raise PackError("%s must be a relative path" % where)
    if ".." in re.split(r"[\\/]", value):
        raise PackError("%s must not have a .. component" % where)
    return base / value
