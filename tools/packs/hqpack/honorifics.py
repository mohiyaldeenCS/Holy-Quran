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
import unicodedata
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
# A code here would be read as markup, collapsed as white space, or refused;
# a control (category Cc, C0 or C1) is refused too.
# U+0026 is one of the site's codes (docs/plans/B07_TAFSIR_PACK.md).
_NOT_A_CODE = KEPT_CODES | frozenset(DOT + "<>\ufeff\ufffd \t\n\r\f\v")
_NOT_IN_A_PHRASE = frozenset("<>&\ufeff\ufffd")
# The conversion collapses every run of ASCII white space (tafsir_html), so a
# phrase holds only single U+0020 between its words and is stored unchanged.
# No other separator (category Z: U+00A0, U+2009, U+2028, U+2029 ...) and no
# control (Cc) may stand in a phrase either.
_WHITE = re.compile("[ \t\n\r\f\v]+")


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
    if c in _NOT_A_CODE or unicodedata.category(c) == "Cc":
        raise PackError(
            "%s %s is markup, white space, a control or a character the conversion keeps" % (where, code_point(c))
        )
    if unicodedata.category(c)[0] == "M":
        raise PackError("%s %s is a combining mark, which would join the character before it" % (where, code_point(c)))
    return c


def _phrase(value, where: str) -> str:
    if not isinstance(value, str) or not value:
        raise PackError("%s is empty" % where)
    if value[0].isspace() or value[-1].isspace():
        raise PackError("%s has spaces at its edges" % where)
    if _WHITE.sub(" ", value) != value:
        raise PackError("%s holds white space other than single U+0020 characters" % where)
    for c in value:
        category = unicodedata.category(c)
        if c in _NOT_IN_A_PHRASE or category == "Cc" or (category[0] == "Z" and c != " "):
            raise PackError("%s holds %s" % (where, code_point(c)))
    return value
