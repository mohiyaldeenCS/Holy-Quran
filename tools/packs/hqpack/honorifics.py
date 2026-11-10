"""The honorific table of the Zaydi-library books (D-188).

`{version, approved_by, approved_on, derived_from_font_sha256,
codes: [{code: "U+00F7", phrase}]}`, strict UTF-8 JSON. The site draws each
code as an honorific with its own font; the approved phrase is what the pack
stores in its place (D-185). The table stays on the owner's machine until it
is approved (D-140 (7)). Messages name fields, indexes and code points only,
never a phrase.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from . import strict_json as sj
from .digest import sha256_bytes
from .errors import PackError, code_point

_KEYS = ("version", "approved_by", "approved_on", "derived_from_font_sha256", "codes")
_CODE_KEYS = ("code", "phrase")
_CODE = re.compile(r"U\+([0-9A-F]{4,6})")

# What D-185 keeps where it stands: a table code among them could not be told
# apart from a kept one.
KEPT_CODES = frozenset("\ufdfa\ufdfb\ufdfd\u00b7")
DOT = "."
# A code here would be read as markup, collapsed as white space, or refused.
# U+0026 is one of the site's codes (docs/plans/B07_TAFSIR_PACK.md).
_NOT_A_CODE = KEPT_CODES | frozenset(DOT + "<>\ufeff\ufffd \t\n\r\f\v")
_NOT_IN_A_PHRASE = frozenset("<>&\ufeff\ufffd")


@dataclass(frozen=True)
class HonorificTable:
    version: int
    approved_by: str
    approved_on: str
    derived_from_font_sha256: str
    phrases: dict  # one-character code -> phrase
    sha256: str  # of the file's bytes


def read_honorific_table(data: bytes) -> HonorificTable:
    try:
        return _table(data)
    except PackError as error:
        raise PackError("honorific table: %s" % error) from None


def _table(data: bytes) -> HonorificTable:
    document = sj.fields(sj.load(data), _KEYS, "the table")
    for key in ("approved_by", "approved_on"):
        if document[key] is None or document[key] == "":
            raise PackError("%s is missing, so the table is not approved" % key)
    approved_by = sj.string(document["approved_by"], "approved_by")
    if approved_by[0].isspace() or approved_by[-1].isspace():
        raise PackError("approved_by has spaces at its edges")
    codes = document["codes"]
    if not isinstance(codes, list) or not codes:
        raise PackError("codes must be a non-empty list")
    phrases = {}
    for index, entry in enumerate(codes):
        where = "codes[%d]" % index
        sj.fields(entry, _CODE_KEYS, where)
        code = _code(entry["code"], where + ".code")
        if code in phrases:
            raise PackError("%s.code %s repeats" % (where, code_point(code)))
        phrases[code] = _phrase(entry["phrase"], where + ".phrase")
    for code, phrase in phrases.items():
        for c in phrase:
            if c in phrases:
                raise PackError("the phrase of %s holds the code %s" % (code_point(code), code_point(c)))
    return HonorificTable(
        version=sj.positive_int(document["version"], "version"),
        approved_by=approved_by,
        approved_on=sj.date(document["approved_on"], "approved_on"),
        derived_from_font_sha256=sj.sha256(document["derived_from_font_sha256"], "derived_from_font_sha256"),
        phrases=phrases,
        sha256=sha256_bytes(data),
    )


def _code(value, where: str) -> str:
    match = _CODE.fullmatch(value) if isinstance(value, str) else None
    if match is None:
        raise PackError("%s is not one character written U+XXXX" % where)
    number = int(match.group(1), 16)
    if number > 0x10FFFF or 0xD800 <= number <= 0xDFFF:
        raise PackError("%s is not a Unicode scalar value" % where)
    c = chr(number)
    if c in _NOT_A_CODE or number < 0x20 or number == 0x7F:
        raise PackError(
            "%s %s is markup, white space, a control or a character the conversion keeps" % (where, code_point(c))
        )
    return c


def _phrase(value, where: str) -> str:
    if not isinstance(value, str) or not value:
        raise PackError("%s is empty" % where)
    if value[0].isspace() or value[-1].isspace():
        raise PackError("%s has spaces at its edges" % where)
    for c in value:
        if c in _NOT_IN_A_PHRASE or ord(c) < 0x20 or ord(c) == 0x7F:
            raise PackError("%s holds %s" % (where, code_point(c)))
    return value
