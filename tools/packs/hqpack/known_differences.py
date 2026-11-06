"""The table of known encoding differences between the KFGQPC and Tanzil Hafs texts (PRD 9.4, D-175).

A strict JSON file, ASCII only, so that no Quran text can enter it:

    {"format": "holyquran-known-differences", "version": 1, "rules": [rule, ...]}

Every rule has `id`, `kind`, `code_points`, `applies_to`, `reason`,
`approved_by` and `date`. Two kinds:

- `presentation`: what the KFGQPC file adds for display, removed from its side
  before comparing, each removal also a check (compare.py). `applies_to` is
  `ayah_end` (`code_points` `{"separator", "first_number_glyph"}`: every ayah
  ends with the separator and the glyph of its own number, first_number_glyph
  + n - 1) or `quarter_start` (`{"sign", "separator"}`: the ayah opens with
  the sign and the separator, exactly at the metadata's quarter starts). At
  most one rule of each.
- `equivalence`: `{"kfgqpc": [...], "tanzil": [...]}`, a KFGQPC sequence that
  stands for a Tanzil sequence. `applies_to` is `every_ayah` or a sorted list
  of addresses `hafs:S:A`. Only a person approves one: the owner and his
  proofreader (D-175).
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass

from .errors import PackError

FORMAT = "holyquran-known-differences"
PRESENTATION = "presentation"
EQUIVALENCE = "equivalence"
AYAH_END = "ayah_end"
QUARTER_START = "quarter_start"
EVERY_AYAH = "every_ayah"
LEAD = "lead"

_TOP_KEYS = ("format", "version", "rules")
_RULE_KEYS = ("id", "kind", "code_points", "applies_to", "reason", "approved_by", "date")
_PRESENTATION_CODE_POINTS = {
    AYAH_END: ("separator", "first_number_glyph"),
    QUARTER_START: ("sign", "separator"),
}
_CODE_POINT = re.compile(r"U\+(?:[0-9A-F]{4,6})\Z")
_ADDRESS = re.compile(r"hafs:([1-9][0-9]*):([1-9][0-9]*)\Z")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}\Z")
_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")


@dataclass(frozen=True)
class Rule:
    id: str
    kind: str
    applies_to: object
    code_points: dict
    approved_by: str
    date: str


@dataclass(frozen=True)
class Table:
    version: int
    ayah_end: object
    quarter_start: object
    equivalences: tuple


def read_table(data: bytes) -> Table:
    try:
        return _read(data)
    except PackError as e:
        raise PackError("known differences: %s" % e) from None


def _read(data):
    if not data.isascii():
        raise PackError("the file holds a byte outside ASCII")
    try:
        document = json.loads(
            data.decode("ascii"), object_pairs_hook=_object, parse_constant=_no_constant
        )
    except json.JSONDecodeError as e:
        raise PackError("invalid JSON at line %d column %d" % (e.lineno, e.colno)) from None
    _keys(document, _TOP_KEYS, "the file")
    if document["format"] != FORMAT:
        raise PackError("format is not %s" % FORMAT)
    version = document["version"]
    if type(version) is not int or version < 1:
        raise PackError("version is not a positive integer")
    if not isinstance(document["rules"], list):
        raise PackError("rules is not an array")
    rules = [_rule(rule, i) for i, rule in enumerate(document["rules"], 1)]
    ids = [rule.id for rule in rules]
    if len(set(ids)) != len(ids):
        raise PackError("two rules share an id")
    presentation = {}
    for rule in rules:
        if rule.kind == PRESENTATION:
            if rule.applies_to in presentation:
                raise PackError(
                    "rules %s and %s are both presentation at %s"
                    % (presentation[rule.applies_to].id, rule.id, rule.applies_to)
                )
            presentation[rule.applies_to] = rule
    return Table(
        version=version,
        ayah_end=presentation.get(AYAH_END),
        quarter_start=presentation.get(QUARTER_START),
        equivalences=tuple(rule for rule in rules if rule.kind == EQUIVALENCE),
    )


def parse_address(address):
    """(surah, ayah) of `hafs:S:A`, or None."""
    match = _ADDRESS.match(address) if isinstance(address, str) else None
    return None if match is None else (int(match.group(1)), int(match.group(2)))


def _rule(rule, index):
    where = "rule %d" % index
    _keys(rule, _RULE_KEYS, where)
    rule_id = rule["id"]
    if not isinstance(rule_id, str) or not _ID.match(rule_id):
        raise PackError("%s: id is not letters, digits, '.', '_' or '-'" % where)
    where = "rule %s" % rule_id
    for key in ("reason", "approved_by"):
        if not isinstance(rule[key], str) or not rule[key].strip():
            raise PackError("%s: %s is empty or not a string" % (where, key))
    if not isinstance(rule["date"], str) or not _DATE.match(rule["date"]):
        raise PackError("%s: date is not YYYY-MM-DD" % where)
    kind = rule["kind"]
    if kind == PRESENTATION:
        applies_to = rule["applies_to"]
        if applies_to not in _PRESENTATION_CODE_POINTS:
            raise PackError(
                "%s: a presentation rule applies to %s or %s" % (where, AYAH_END, QUARTER_START)
            )
        code_points = _code_point_object(
            rule["code_points"], _PRESENTATION_CODE_POINTS[applies_to], where
        )
        code_points = {key: value[0] for key, value in code_points.items()}
    elif kind == EQUIVALENCE:
        applies_to = _equivalence_scope(rule["applies_to"], where)
        code_points = _code_point_object(rule["code_points"], ("kfgqpc", "tanzil"), where, lists=True)
        if not code_points["kfgqpc"]:
            raise PackError("%s: the kfgqpc sequence is empty" % where)
        if code_points["kfgqpc"] == code_points["tanzil"]:
            raise PackError("%s: the two sequences are equal" % where)
        if rule["approved_by"].lstrip().lower().startswith(LEAD):
            raise PackError(
                "%s: an equivalence is approved by the owner and his proofreader, not the lead" % where
            )
    else:
        raise PackError("%s: kind is not %s or %s" % (where, PRESENTATION, EQUIVALENCE))
    return Rule(
        id=rule_id,
        kind=kind,
        applies_to=applies_to,
        code_points=code_points,
        approved_by=rule["approved_by"],
        date=rule["date"],
    )


def _equivalence_scope(value, where):
    if value == EVERY_AYAH:
        return value
    if not isinstance(value, list) or not value:
        raise PackError("%s: applies_to is not %s or a list of addresses" % (where, EVERY_AYAH))
    addresses = []
    for item in value:
        address = parse_address(item)
        if address is None:
            raise PackError("%s: applies_to holds an entry that is not hafs:S:A" % where)
        addresses.append(address)
    if addresses != sorted(set(addresses)):
        raise PackError("%s: applies_to is not sorted and unique" % where)
    return tuple(addresses)


def _code_point_object(value, keys, where, lists=False):
    _keys(value, keys, where + " code_points")
    result = {}
    for key in keys:
        items = value[key] if lists else [value[key]]
        if not isinstance(items, list):
            raise PackError("%s: code_points.%s is not an array" % (where, key))
        result[key] = tuple(_code_point(item, "%s: code_points.%s" % (where, key)) for item in items)
    return result


def _code_point(value, where):
    if not isinstance(value, str) or not _CODE_POINT.match(value):
        raise PackError("%s holds an entry that is not U+XXXX" % where)
    cp = int(value[2:], 16)
    if cp > 0x10FFFF or 0xD800 <= cp <= 0xDFFF or "U+%04X" % cp != value:
        raise PackError("%s holds %s, which is not a code point written U+XXXX" % (where, value))
    return cp


def _keys(value, keys, where):
    if not isinstance(value, dict):
        raise PackError("%s is not an object" % where)
    for key in keys:
        if key not in value:
            raise PackError("%s lacks %s" % (where, key))
    if len(value) != len(keys):
        raise PackError("%s has a key other than %s" % (where, ", ".join(keys)))


def _object(pairs):
    names = [name for name, _ in pairs]
    if len(set(names)) != len(names):
        raise PackError("an object repeats a key")
    return dict(pairs)


def _no_constant(name):
    raise PackError("the file holds %s, which is not JSON" % name)
