"""Strict JSON for the tafsir build's inputs: UTF-8 without a BOM, no repeated
key, no NaN or Infinity, and objects with exactly the keys expected. Messages
name JSON paths, never a value.
"""

from __future__ import annotations

import datetime
import json
import re

from .errors import PackError

_NAMEABLE_KEY = re.compile(r"[A-Za-z0-9_]{1,64}")
_SHA256 = re.compile(r"[0-9a-f]{64}")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")


def load(data: bytes, ascii_only=False):
    if ascii_only and not data.isascii():
        raise PackError("the file is not ASCII")
    if data.startswith(b"\xef\xbb\xbf"):
        raise PackError("the file starts with a byte order mark")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PackError("not UTF-8 at byte %d" % error.start) from None
    return loads(text)


def loads(text: str):
    try:
        return json.loads(text, object_pairs_hook=_unique_keys, parse_constant=_refuse_constant)
    except json.JSONDecodeError as error:
        raise PackError("not JSON at line %d column %d" % (error.lineno, error.colno)) from None


def fields(value, keys, where: str, optional=()) -> dict:
    """`value` as an object holding every key of `keys`, and perhaps those of `optional`, and no other."""
    if not isinstance(value, dict):
        raise PackError("%s is not an object" % where)
    for key in value:
        if key not in keys and key not in optional:
            raise PackError("%s has an unknown key %s" % (where, key_name(key)))
    for key in keys:
        if key not in value:
            raise PackError("%s.%s is missing" % (where, key))
    return value


def string(value, where: str) -> str:
    if not isinstance(value, str) or not value:
        raise PackError("%s must be a non-empty string" % where)
    return value


def positive_int(value, where: str) -> int:
    if type(value) is not int or value < 1:
        raise PackError("%s must be a positive integer" % where)
    return value


def date(value, where: str) -> str:
    if isinstance(value, str) and _DATE.fullmatch(value):
        try:
            datetime.date.fromisoformat(value)
            return value
        except ValueError:
            pass
    raise PackError("%s must be a real date written YYYY-MM-DD" % where)


def sha256(value, where: str) -> str:
    if not isinstance(value, str) or not _SHA256.fullmatch(value):
        raise PackError("%s must be lowercase hex SHA-256" % where)
    return value


def key_name(key) -> str:
    return key if isinstance(key, str) and _NAMEABLE_KEY.fullmatch(key) else "(a key that is not plain ASCII)"


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PackError("a repeated key %s" % key_name(key))
        result[key] = value
    return result


def _refuse_constant(name):
    raise PackError("%s is not a JSON number" % name)
