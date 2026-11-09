"""The table of known encoding differences between the KFGQPC and Tanzil Hafs texts (PRD 9.4, D-175).

A strict JSON file, ASCII only, so that no Quran text can enter it:

    {"format": "holyquran-known-differences", "version": 2, "rules": [rule, ...]}

Every rule has `id`, `kind`, `code_points`, `applies_to`, `reason`,
`approved_by` and `date`. Two kinds:

- `presentation`: what the KFGQPC file adds for display, removed from its side
  before comparing, each removal also a check (compare.py). `applies_to` is
  `ayah_end` (`code_points` `{"separator", "first_number_glyph"}`: every ayah
  ends with the separator and the glyph of its own number, first_number_glyph
  + n - 1), `quarter_start` (`{"sign", "separator"}`: the ayah opens with the
  sign and the separator where KFGQPC starts a quarter),
  `surah_opening_quarter_start` (`{"sign"}`, the quarter_start rule's sign:
  a quarter start of the metadata that is the first ayah of a surah carries
  no sign) or a sorted list of addresses (`{"separator"}`, a space character
  of Unicode category Zs: at those ayat the ayah_end separator is this one
  instead). At most one rule of each named
  kind; an address is listed by one rule at most.
- `equivalence`: `{"kfgqpc": [...], "tanzil": [...]}`, a KFGQPC sequence that
  stands for a Tanzil sequence. `applies_to` is `every_ayah` or a sorted list
  of addresses `hafs:S:A`. Only a person approves one: the owner and his
  proofreader (D-175).
"""

from __future__ import annotations

import datetime
import json
import re
import unicodedata
from dataclasses import dataclass

from .errors import PackError, code_point

FORMAT = "holyquran-known-differences"
PRESENTATION = "presentation"
EQUIVALENCE = "equivalence"
AYAH_END = "ayah_end"
QUARTER_START = "quarter_start"
SURAH_OPENING_QUARTER_START = "surah_opening_quarter_start"
EVERY_AYAH = "every_ayah"
LEAD = "lead"

_TOP_KEYS = ("format", "version", "rules")
_RULE_KEYS = ("id", "kind", "code_points", "applies_to", "reason", "approved_by", "date")
_PRESENTATION_CODE_POINTS = {
    AYAH_END: ("separator", "first_number_glyph"),
    QUARTER_START: ("sign", "separator"),
    SURAH_OPENING_QUARTER_START: ("sign",),
}
_SEPARATOR_AT_ADDRESSES = ("separator",)
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
    ayah_end_separators: tuple
    quarter_start: object
    surah_opening_quarter_start: object
    equivalences: tuple

    def ayah_end_rule_at(self, address):
        """The address-listed separator rule of `address`, or None."""
        for rule in self.ayah_end_separators:
            if address in rule.applies_to:
                return rule
        return None


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
    separators = []
    listed = {}
    for rule in rules:
        if rule.kind != PRESENTATION:
            continue
        if isinstance(rule.applies_to, tuple):
            for address in rule.applies_to:
                if address in listed:
                    raise PackError(
                        "rules %s and %s both list hafs:%d:%d"
                        % ((listed[address], rule.id) + address)
                    )
                listed[address] = rule.id
            separators.append(rule)
            continue
        if rule.applies_to in presentation:
            raise PackError(
                "rules %s and %s are both presentation at %s"
                % (presentation[rule.applies_to].id, rule.id, rule.applies_to)
            )
        presentation[rule.applies_to] = rule
    table = Table(
        version=version,
        ayah_end=presentation.get(AYAH_END),
        ayah_end_separators=tuple(separators),
        quarter_start=presentation.get(QUARTER_START),
        surah_opening_quarter_start=presentation.get(SURAH_OPENING_QUARTER_START),
        equivalences=tuple(rule for rule in rules if rule.kind == EQUIVALENCE),
    )
    _check_dependencies(table)
    return table


def _check_dependencies(table):
    opening = table.surah_opening_quarter_start
    if opening is not None:
        quarter = table.quarter_start
        if quarter is None:
            raise PackError("rule %s needs a presentation rule at %s" % (opening.id, QUARTER_START))
        if opening.code_points["sign"] != quarter.code_points["sign"]:
            raise PackError("rule %s names another sign than rule %s" % (opening.id, quarter.id))
    for rule in table.ayah_end_separators:
        end = table.ayah_end
        if end is None:
            raise PackError("rule %s needs a presentation rule at %s" % (rule.id, AYAH_END))
        if rule.code_points["separator"] == end.code_points["separator"]:
            raise PackError("rule %s names the separator of rule %s" % (rule.id, end.id))


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
    try:
        datetime.date.fromisoformat(rule["date"])
    except ValueError:
        raise PackError("%s: date %s is not a day of the calendar" % (where, rule["date"])) from None
    kind = rule["kind"]
    if kind == PRESENTATION:
        applies_to = rule["applies_to"]
        if isinstance(applies_to, list):
            applies_to = _addresses(applies_to, where)
            keys = _SEPARATOR_AT_ADDRESSES
        elif isinstance(applies_to, str) and applies_to in _PRESENTATION_CODE_POINTS:
            keys = _PRESENTATION_CODE_POINTS[applies_to]
        else:
            raise PackError(
                "%s: a presentation rule applies to %s, %s, %s or a list of addresses"
                % (where, AYAH_END, QUARTER_START, SURAH_OPENING_QUARTER_START)
            )
        code_points = _code_point_object(rule["code_points"], keys, where)
        code_points = {key: value[0] for key, value in code_points.items()}
        if keys == _SEPARATOR_AT_ADDRESSES and unicodedata.category(chr(code_points["separator"])) != "Zs":
            raise PackError(
                "%s: the separator %s is not a space character (Unicode category Zs)"
                % (where, code_point(code_points["separator"]))
            )
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
    if not isinstance(value, list):
        raise PackError("%s: applies_to is not %s or a list of addresses" % (where, EVERY_AYAH))
    return _addresses(value, where)


def _addresses(value, where):
    if not value:
        raise PackError("%s: applies_to is an empty list" % where)
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
