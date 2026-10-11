import hashlib
import struct
import unittest
from pathlib import Path

from hqpack.errors import PackError
from hqpack.font import read_font

AMIRI_QURAN = Path(__file__).resolve().parents[3] / "assets/fonts/AmiriQuran-Regular.ttf"


def sfnt(tables, version=b"\x00\x01\x00\x00"):
    header = version + struct.pack(">HHHH", len(tables), 0, 0, 0)
    offset = len(header) + 16 * len(tables)
    directory = b""
    body = b""
    for tag, data in tables:
        directory += tag + struct.pack(">III", 0, offset + len(body), len(data))
        body += data
    return header + directory + body


def name_table(records):
    strings = b""
    entries = b""
    for platform, encoding, language, name_id, value in records:
        data = value.encode("utf-16-be")
        entries += struct.pack(">HHHHHH", platform, encoding, language, name_id, len(data), len(strings))
        strings += data
    return struct.pack(">HHH", 0, len(records), 6 + len(entries)) + entries + strings


def windows_names(**names):
    return name_table([(3, 1, 0x409, int(k[2:]), v) for k, v in names.items()])


def format4(segments):
    """Segments are (start, end, delta, glyphs or None); a 0xFFFF one is added."""
    segments = list(segments) + [(0xFFFF, 0xFFFF, 1, None)]
    count = len(segments)
    ends = b"".join(struct.pack(">H", s[1]) for s in segments)
    starts = b"".join(struct.pack(">H", s[0]) for s in segments)
    deltas = b"".join(struct.pack(">H", s[2] & 0xFFFF) for s in segments)
    range_offsets = b""
    glyphs = b""
    for i, (_, _, _, ids) in enumerate(segments):
        if ids is None:
            range_offsets += struct.pack(">H", 0)
        else:
            range_offsets += struct.pack(">H", 2 * (count - i) + len(glyphs))
            glyphs += b"".join(struct.pack(">H", g) for g in ids)
    body = ends + b"\x00\x00" + starts + deltas + range_offsets + glyphs
    return struct.pack(">HHHHHHH", 4, 14 + len(body), 0, 2 * count, 0, 0, 0) + body


def format12(groups):
    body = b"".join(struct.pack(">III", *g) for g in groups)
    return struct.pack(">HHIII", 12, 0, 16 + len(body), 0, len(groups)) + body


def cmap_table(subtables):
    header = struct.pack(">HH", 0, len(subtables))
    offset = 4 + 8 * len(subtables)
    records = b""
    body = b""
    for platform, encoding, data in subtables:
        records += struct.pack(">HHI", platform, encoding, offset + len(body))
        body += data
    return header + records + body


SIMPLE_CMAP = cmap_table([(3, 1, format4([(0x41, 0x43, -0x40, None)]))])
SIMPLE_NAMES = windows_names(id1="Synthetic", id5="Version 2.010; synthetic")


class AmiriQuranTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = AMIRI_QURAN.read_bytes()
        cls.font = read_font(cls.data)

    def test_names_as_the_app_reads_them(self):
        self.assertEqual(self.font.family, "Amiri Quran")
        self.assertEqual(self.font.version, "1.003")

    def test_hash(self):
        self.assertEqual(self.font.sha256, hashlib.sha256(self.data).hexdigest())
        self.assertRegex(self.font.sha256, "^[0-9a-f]{64}$")

    def test_coverage(self):
        for cp in (0x0020, 0x0041, 0x0646, 0x06D6, 0x06E9, 0x0640):
            self.assertIn(cp, self.font.code_points, hex(cp))
        for cp in (0x00E9, 0x1F600, 0xFFFF):
            self.assertNotIn(cp, self.font.code_points, hex(cp))


class SyntheticFontTest(unittest.TestCase):
    def assertRefused(self, data, *parts):
        with self.assertRaises(PackError) as caught:
            read_font(data)
        message = str(caught.exception)
        message.encode("ascii")
        for part in parts:
            self.assertIn(part, message)

    def test_format4_with_delta(self):
        font = read_font(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", SIMPLE_NAMES)]))
        self.assertEqual(font.code_points, frozenset({0x41, 0x42, 0x43}))
        self.assertEqual(font.family, "Synthetic")
        self.assertEqual(font.version, "2.010")

    def test_format4_glyph_array_skips_zero_and_applies_delta(self):
        cmap = cmap_table([(3, 1, format4([
            (0x10, 0x13, 0, [5, 0, 7, 0]),
            (0x20, 0x21, -5, [5, 6]),
            (0x30, 0x30, -0x30, None),
        ]))])
        font = read_font(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]))
        self.assertEqual(font.code_points, frozenset({0x10, 0x12, 0x21}))

    def test_format4_skips_ffff(self):
        cmap = cmap_table([(3, 1, format4([(0xFFF0, 0xFFFE, 1, None)]))])
        font = read_font(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]))
        self.assertEqual(font.code_points, frozenset(range(0xFFF0, 0xFFFF)))

    def test_format12_union_with_format4(self):
        cmap = cmap_table([
            (3, 1, format4([(0x41, 0x41, 1, None)])),
            (3, 10, format12([(0x1F600, 0x1F601, 3), (0x0, 0x2, 0)])),
        ])
        font = read_font(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]))
        self.assertEqual(font.code_points, frozenset({0x41, 0x1F600, 0x1F601, 0x1, 0x2}))

    def test_format12_on_unicode_platform(self):
        cmap = cmap_table([(0, 4, format12([(0x10330, 0x10331, 9)]))])
        font = read_font(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)], version=b"OTTO"))
        self.assertEqual(font.code_points, frozenset({0x10330, 0x10331}))

    def test_ignores_other_subtables(self):
        cmap = cmap_table([
            (1, 0, format4([(0x61, 0x61, 1, None)])),
            (3, 1, format12([(0x62, 0x62, 1)])),
            (3, 1, format4([(0x41, 0x41, 1, None)])),
        ])
        font = read_font(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]))
        self.assertEqual(font.code_points, frozenset({0x41}))

    def test_no_usable_cmap(self):
        cmap = cmap_table([(1, 0, format4([(0x61, 0x61, 1, None)]))])
        self.assertRefused(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]), "cmap subtable")

    def test_family_prefers_id16(self):
        names = windows_names(id1="Legacy", id16="Typographic", id5="Version 1.5")
        font = read_font(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", names)]))
        self.assertEqual(font.family, "Typographic")

    def test_family_falls_back_to_id1(self):
        names = name_table([
            (1, 0, 0, 16, "Mac"),
            (3, 1, 0x40C, 16, "French"),
            (3, 1, 0x409, 1, "Legacy"),
            (3, 1, 0x409, 5, "Version 3.25"),
        ])
        font = read_font(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", names)]))
        self.assertEqual(font.family, "Legacy")
        self.assertEqual(font.version, "3.25")

    def test_no_family(self):
        names = windows_names(id5="Version 1.0")
        self.assertRefused(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", names)]), "family")

    def test_bad_versions(self):
        for value in ("1.003", "Version 1", "version 1.0", " Version 1.0", "Version \u0661.\u0662"):
            with self.subTest(value=value):
                names = windows_names(id1="Synthetic", id5=value)
                self.assertRefused(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", names)]), "name ID 5")
        names = windows_names(id1="Synthetic")
        self.assertRefused(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", names)]), "name ID 5")

    def test_missing_tables(self):
        self.assertRefused(sfnt([(b"cmap", SIMPLE_CMAP)]), "no name table")
        self.assertRefused(sfnt([(b"name", SIMPLE_NAMES)]), "no cmap table")

    def test_not_an_sfnt(self):
        for data in (b"", b"wOFF" + bytes(40), b"ttcf" + bytes(40), b"true" + bytes(40)):
            with self.subTest(data=data[:4]):
                self.assertRefused(data, "not a TrueType or OpenType font")

    def test_repeated_table(self):
        self.assertRefused(
            sfnt([(b"cmap", SIMPLE_CMAP), (b"name", SIMPLE_NAMES), (b"name", SIMPLE_NAMES)]),
            "repeats a tag",
        )

    def test_odd_name_length(self):
        names = bytearray(SIMPLE_NAMES)
        struct.pack_into(">H", names, 6 + 8, 3)
        self.assertRefused(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", bytes(names))]), "name ID 1")

    def test_every_truncation_is_a_pack_error(self):
        cmap = cmap_table([
            (3, 1, format4([(0x10, 0x13, 0, [5, 0, 7, 0])])),
            (3, 10, format12([(0x1F600, 0x1F601, 3)])),
        ])
        data = sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)])
        read_font(data)
        for length in range(len(data)):
            with self.subTest(length=length):
                with self.assertRaises(PackError):
                    read_font(data[:length])

    def test_table_counts_past_the_end(self):
        data = bytearray(sfnt([(b"cmap", SIMPLE_CMAP), (b"name", SIMPLE_NAMES)]))
        struct.pack_into(">H", data, 4, 40)
        self.assertRefused(bytes(data), "table record")

    def test_corrupt_offsets_are_pack_errors(self):
        data = sfnt([(b"cmap", SIMPLE_CMAP), (b"name", SIMPLE_NAMES)])
        for at in range(len(data)):
            corrupt = bytearray(data)
            corrupt[at] ^= 0xFF
            with self.subTest(at=at):
                try:
                    read_font(bytes(corrupt))
                except PackError:
                    pass

    def test_malformed_format12_group(self):
        for group in ((5, 4, 1), (0x10FFFF, 0x110000, 1)):
            with self.subTest(group=group):
                cmap = cmap_table([(3, 10, format12([group]))])
                self.assertRefused(sfnt([(b"cmap", cmap), (b"name", SIMPLE_NAMES)]), "group 0")


if __name__ == "__main__":
    unittest.main()
