"""The font a text pack names: its hash, family, version and code points.

The name records are read the way the app's integrity suite reads them:
platform 3, encoding 1, language 0x409, the first matching record.
"""

from __future__ import annotations

import hashlib
import re
import struct
from dataclasses import dataclass

from .errors import PackError

_SFNT_VERSIONS = (b"\x00\x01\x00\x00", b"OTTO")
_VERSION = re.compile(r"Version ([0-9]+\.[0-9]+)")
_NAME_FAMILY = 16
_NAME_LEGACY_FAMILY = 1
_NAME_VERSION = 5
_UCS4 = (3, 10)


@dataclass(frozen=True)
class FontInfo:
    family: str
    version: str
    sha256: str
    code_points: frozenset


def read_font(data: bytes) -> FontInfo:
    tables = _tables(data)
    name = _table(tables, b"name")
    family = _name(name, _NAME_FAMILY)
    if family is None:
        family = _name(name, _NAME_LEGACY_FAMILY)
    if family is None:
        raise PackError("the font has no family name (name ID 16 or 1)")
    version = _VERSION.match(_name(name, _NAME_VERSION) or "")
    if version is None:
        raise PackError('name ID 5 of the font does not start with "Version d.d"')
    return FontInfo(
        family=family,
        version=version.group(1),
        sha256=hashlib.sha256(data).hexdigest(),
        code_points=frozenset(_cmap(_table(tables, b"cmap"))),
    )


def _u16(data: bytes, offset: int, what: str) -> int:
    return _unpack(">H", data, offset, what)


def _u32(data: bytes, offset: int, what: str) -> int:
    return _unpack(">I", data, offset, what)


def _unpack(fmt: str, data: bytes, offset: int, what: str) -> int:
    size = struct.calcsize(fmt)
    if offset < 0 or offset + size > len(data):
        raise PackError("the font is truncated in %s at byte %d" % (what, offset))
    return struct.unpack_from(fmt, data, offset)[0]


def _tables(data: bytes) -> dict:
    if data[:4] not in _SFNT_VERSIONS:
        raise PackError("the font is not a TrueType or OpenType font")
    tables = {}
    for i in range(_u16(data, 4, "the table directory")):
        entry = 12 + 16 * i
        if entry + 16 > len(data):
            raise PackError("the font is truncated in table record %d" % i)
        tag = data[entry : entry + 4]
        offset = _u32(data, entry + 8, "the table directory")
        length = _u32(data, entry + 12, "the table directory")
        if offset + length > len(data):
            raise PackError("table record %d of the font runs past its end" % i)
        if tag in tables:
            raise PackError("table record %d of the font repeats a tag" % i)
        tables[tag] = data[offset : offset + length]
    return tables


def _table(tables: dict, tag: bytes) -> bytes:
    if tag not in tables:
        raise PackError("the font has no %s table" % tag.decode("ascii"))
    return tables[tag]


def _name(table: bytes, name_id: int):
    count = _u16(table, 2, "the name table")
    strings = _u16(table, 4, "the name table")
    for j in range(count):
        record = 6 + 12 * j
        key = tuple(_u16(table, record + 2 * k, "the name table") for k in range(4))
        if key != (3, 1, 0x409, name_id):
            continue
        length = _u16(table, record + 8, "the name table")
        start = strings + _u16(table, record + 10, "the name table")
        if start + length > len(table) or length % 2:
            raise PackError("name ID %d of the font is malformed" % name_id)
        try:
            return table[start : start + length].decode("utf-16-be")
        except UnicodeDecodeError:
            raise PackError("name ID %d of the font is not UTF-16" % name_id) from None
    return None


def _cmap(table: bytes) -> set:
    code_points = set()
    found = False
    for i in range(_u16(table, 2, "the cmap table")):
        record = 4 + 8 * i
        platform = _u16(table, record, "the cmap table")
        encoding = _u16(table, record + 2, "the cmap table")
        offset = _u32(table, record + 4, "the cmap table")
        subtable_format = _u16(table, offset, "a cmap subtable")
        if (platform, encoding, subtable_format) == (3, 1, 4):
            code_points |= _format4(table, offset)
        elif subtable_format == 12 and (platform == 0 or (platform, encoding) == _UCS4):
            code_points |= _format12(table, offset)
        else:
            continue
        found = True
    if not found:
        raise PackError("the font has no cmap subtable of format 4 (3, 1) or 12")
    return code_points


def _format4(table: bytes, base: int) -> set:
    what = "a cmap subtable of format 4"
    seg_count_x2 = _u16(table, base + 6, what)
    if seg_count_x2 % 2:
        raise PackError("%s has an odd segCountX2" % what)
    ends = base + 14
    starts = ends + seg_count_x2 + 2
    deltas = starts + seg_count_x2
    range_offsets = deltas + seg_count_x2
    code_points = set()
    for i in range(0, seg_count_x2, 2):
        end = _u16(table, ends + i, what)
        start = _u16(table, starts + i, what)
        delta = _u16(table, deltas + i, what)
        range_offset_at = range_offsets + i
        range_offset = _u16(table, range_offset_at, what)
        for c in range(start, end + 1):
            if c == 0xFFFF:
                continue
            if range_offset == 0:
                glyph = (c + delta) & 0xFFFF
            else:
                at = range_offset_at + range_offset + 2 * (c - start)
                glyph = _u16(table, at, what)
                if glyph:
                    glyph = (glyph + delta) & 0xFFFF
            if glyph:
                code_points.add(c)
    return code_points


def _format12(table: bytes, base: int) -> set:
    what = "a cmap subtable of format 12"
    code_points = set()
    for k in range(_u32(table, base + 12, what)):
        group = base + 16 + 12 * k
        start = _u32(table, group, what)
        end = _u32(table, group + 4, what)
        glyph = _u32(table, group + 8, what)
        if start > end or end > 0x10FFFF:
            raise PackError("group %d of %s is malformed" % (k, what))
        first = start + 1 if glyph == 0 else start
        code_points.update(range(first, end + 1))
    return code_points
