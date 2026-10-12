from __future__ import annotations

import hashlib
import json
import re
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import synthetic_source
from hqpack.config import read_build_config

PACKS = Path(__file__).resolve().parent.parent
FONT = PACKS.parent.parent / "assets" / "fonts" / "AmiriQuran-Regular.ttf"

# The expected source, written independently of synthetic_source.py.
EXPECTED_AYAT = {
    (1, 1): "Synthetic ayah one",
    (1, 2): "Synthetic \u06d6 two \u06e9",
    (1, 3): "\u06da Synthetic three",
    (1, 4): " \u0646\u064e\u0635 \u062a\u062c\u0631\u064a\u0628\u064a  ",
    (2, 1): "Synthetic  double  spaces",
    (2, 2): "Synthetic \u0640 \u06e5 tatweel-and-small-waw \u06d7",
    (2, 3): "Synthetic-pair joined \u06e9",
    (3, 1): "Synthetic last ayah",
}
EXPECTED_BASMALA = {1: "Synthetic opening line", 3: "Synthetic opening line"}
EXPECTED_NAMES = {
    1: "Synthetic surah one",
    2: "Synthetic surah two",
    3: "Synthetic surah three",
}

_SURA = re.compile(r'<sura index="(\d+)" name="([^"]*)">')
_AYA = re.compile(r'<aya index="(\d+)" text="([^"]*)"(?: bismillah="([^"]*)")? />')
_VALUE = re.compile(r'="([^"]*)"')


def _parse_text(xml: str):
    names, ayat, basmala = {}, {}, {}
    surah = None
    for line in xml.split("\n"):
        sura = _SURA.search(line)
        if sura:
            surah = int(sura.group(1))
            names[surah] = sura.group(2)
        aya = _AYA.search(line)
        if aya:
            number = int(aya.group(1))
            ayat[(surah, number)] = aya.group(2)
            if aya.group(3) is not None:
                basmala[surah] = aya.group(3)
    return names, ayat, basmala


def _cmap_code_points(data: bytes) -> set:
    """Code points that map to a glyph other than 0 in cmap formats 4 and 12."""
    tables = struct.unpack_from(">H", data, 4)[0]
    cmap = None
    for i in range(tables):
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        if tag == b"cmap":
            cmap = offset
    subtables = struct.unpack_from(">H", data, cmap + 2)[0]
    found = set()
    for i in range(subtables):
        _, _, offset = struct.unpack_from(">HHI", data, cmap + 4 + 8 * i)
        start = cmap + offset
        form = struct.unpack_from(">H", data, start)[0]
        if form == 4:
            found |= _format4(data, start)
        elif form == 12:
            found |= _format12(data, start)
    return found


def _format4(data, start):
    segments = struct.unpack_from(">H", data, start + 6)[0] // 2
    ends_at = start + 14
    starts_at = ends_at + 2 * segments + 2
    deltas_at = starts_at + 2 * segments
    ranges_at = deltas_at + 2 * segments
    found = set()
    for s in range(segments):
        end, first, delta, range_offset = (
            struct.unpack_from(">H", data, at + 2 * s)[0]
            for at in (ends_at, starts_at, deltas_at, ranges_at)
        )
        for c in range(first, end + 1):
            if c == 0xFFFF:
                continue
            if range_offset == 0:
                glyph = (c + delta) & 0xFFFF
            else:
                at = ranges_at + 2 * s + range_offset + 2 * (c - first)
                glyph = struct.unpack_from(">H", data, at)[0]
                glyph = (glyph + delta) & 0xFFFF if glyph else 0
            if glyph:
                found.add(c)
    return found


def _format12(data, start):
    groups = struct.unpack_from(">I", data, start + 12)[0]
    found = set()
    for g in range(groups):
        first, end, glyph = struct.unpack_from(">III", data, start + 16 + 12 * g)
        found.update(c for c in range(first, end + 1) if glyph + c - first)
    return found


class SyntheticSourceTest(unittest.TestCase):
    def setUp(self):
        self._work = tempfile.TemporaryDirectory()
        self.directory = Path(self._work.name)

    def tearDown(self):
        self._work.cleanup()

    def test_writes_the_four_files_and_a_description_that_reads_back(self):
        build = synthetic_source.write_synthetic_source(self.directory)
        self.assertEqual(build, self.directory / "build.json")
        self.assertEqual(
            sorted(p.name for p in self.directory.iterdir()),
            ["build.json", "marks.json", "metadata.xml", "text.xml"],
        )
        config = read_build_config(build)
        text = (self.directory / "text.xml").read_bytes()
        metadata = (self.directory / "metadata.xml").read_bytes()
        self.assertEqual(config.text.file, build.resolve().parent / "text.xml")
        self.assertEqual(config.text.file_sha256, hashlib.sha256(text).hexdigest())
        self.assertEqual(config.edition_map.file, build.resolve().parent / "metadata.xml")
        self.assertEqual(
            config.edition_map.file_sha256, hashlib.sha256(metadata).hexdigest()
        )
        self.assertEqual(config.mark_table, build.resolve().parent / "marks.json")
        self.assertEqual(config.pack_id, "synthetic-text")
        self.assertEqual(config.riwaya, "synthetic")
        self.assertEqual(config.text.registry_row, 1)
        self.assertEqual(config.edition_map.registry_row, 4)

    def test_output_is_deterministic(self):
        first = self.directory / "a"
        second = self.directory / "b"
        synthetic_source.write_synthetic_source(first)
        synthetic_source.write_synthetic_source(second)
        for name in ("build.json", "marks.json", "metadata.xml", "text.xml"):
            self.assertEqual((first / name).read_bytes(), (second / name).read_bytes())

    def test_overrides_replace_top_level_keys(self):
        build = synthetic_source.write_synthetic_source(self.directory, riwaya="hafs")
        self.assertEqual(read_build_config(build).riwaya, "hafs")

    def test_given_files_are_written_and_hashed(self):
        text = synthetic_source.synthetic_text_xml(
            surahs=(("Synthetic variant", None, ("Synthetic only",)),)
        )
        build = synthetic_source.write_synthetic_source(self.directory, text_xml=text)
        self.assertEqual((self.directory / "text.xml").read_bytes(), text)
        self.assertEqual(
            read_build_config(build).text.file_sha256, hashlib.sha256(text).hexdigest()
        )

    def test_build_description_is_written_as_specified(self):
        build = synthetic_source.write_synthetic_source(self.directory)
        data = build.read_bytes()
        document = json.loads(data.decode("utf-8"))
        self.assertEqual(
            data,
            (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
        )
        self.assertEqual(
            document["sources"]["text"]["url"],
            "https://example.invalid/synthetic/text"
            "?marks=true&sajdah=true&rub=false&outType=xml&agree=true",
        )
        self.assertIsNone(document["sources"]["text"]["licence"]["text"])

    def test_runs_as_a_script(self):
        target = self.directory / "out"
        completed = subprocess.run(
            [sys.executable, str(PACKS / "synthetic_source.py"), str(target)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(
            sorted(p.name for p in target.iterdir()),
            ["build.json", "marks.json", "metadata.xml", "text.xml"],
        )
        read_build_config(target / "build.json")


class TextXmlTest(unittest.TestCase):
    def setUp(self):
        self.data = synthetic_source.synthetic_text_xml()
        self.xml = self.data.decode("utf-8")

    def test_holds_exactly_the_expected_values(self):
        names, ayat, basmala = _parse_text(self.xml)
        self.assertEqual(names, EXPECTED_NAMES)
        self.assertEqual(ayat, EXPECTED_AYAT)
        self.assertEqual(basmala, EXPECTED_BASMALA)
        self.assertEqual(self.xml.count("<aya "), len(EXPECTED_AYAT))

    def test_has_the_tanzil_form_and_one_notice_after_the_root(self):
        self.assertTrue(
            self.data.startswith(b'<?xml version="1.0" encoding="utf-8" ?>\n<quran>\n')
        )
        self.assertEqual(self.xml.count("<!--"), 1)
        self.assertTrue(self.xml.endswith("</quran>\n\n<!--%s-->\n" % synthetic_source.TEXT_NOTICE))
        self.assertEqual(
            synthetic_source.TEXT_NOTICE,
            "\nSynthetic text source for tests. Not Quran text.\nVersion 1\n",
        )

    def test_holds_no_reference_tab_carriage_return_or_bom(self):
        for forbidden in ("&", "\t", "\r", "\ufeff"):
            self.assertNotIn(forbidden, self.xml)
        self.assertFalse(self.data.startswith(b"\xef\xbb\xbf"))

    def test_generator_refuses_a_value_the_form_cannot_hold(self):
        for bad in ("a&b", "a<b", 'a"b', "a\tb", "a\nb", "a\rb"):
            with self.subTest(value=bad):
                with self.assertRaises(ValueError):
                    synthetic_source.synthetic_text_xml(
                        surahs=(("Synthetic", None, (bad,)),)
                    )

    def test_every_code_point_is_in_the_quran_font(self):
        font_code_points = _cmap_code_points(FONT.read_bytes())
        values = _VALUE.findall(self.xml)
        values += _VALUE.findall(synthetic_source.synthetic_metadata_xml().decode("utf-8"))
        used = {ord(c) for value in values for c in value}
        missing = sorted("U+%04X" % c for c in used - font_code_points)
        self.assertEqual(missing, [])
        self.assertIn(0x064E, used)


class MetadataXmlTest(unittest.TestCase):
    def setUp(self):
        self.xml = synthetic_source.synthetic_metadata_xml().decode("utf-8")

    def test_has_one_notice_before_the_root(self):
        notice = "<!--%s-->" % synthetic_source.METADATA_NOTICE
        self.assertTrue(
            self.xml.startswith('<?xml version="1.0" encoding="utf-8" ?>\n' + notice + "\n")
        )
        self.assertEqual(self.xml.count("<!--"), 1)
        self.assertIn(
            '<quran type="metadata" version="1.0" copyright="Synthetic" license="synthetic">',
            self.xml,
        )

    def test_groups_come_in_order(self):
        groups = re.findall(r"^  <(\w+)[ >]", self.xml, re.M)
        self.assertEqual(
            groups, ["suras", "juzs", "hizbs", "manzils", "rukus", "pages", "sajdas"]
        )

    def test_surahs_agree_with_the_text(self):
        suras = re.findall(
            r'<sura index="(\d+)" ayas="(\d+)" start="(\d+)" name="([^"]*)"', self.xml
        )
        self.assertEqual(
            suras,
            [("1", "4", "0", "Synthetic surah one"),
             ("2", "3", "4", "Synthetic surah two"),
             ("3", "1", "7", "Synthetic surah three")],
        )
        self.assertIn(
            '<sura index="2" ayas="3" start="4" name="Synthetic surah two" '
            'tname="Synthetic-Two" ename="Synthetic Two" type="Medinan" order="1" '
            'rukus="1" />',
            self.xml,
        )

    def test_points_and_sajdas(self):
        def points(element):
            return re.findall(r'<%s index="(\d+)" sura="(\d+)" aya="(\d+)"' % element, self.xml)

        self.assertEqual(points("juz"), [("1", "1", "1"), ("2", "2", "1")])
        self.assertEqual(
            [(s, a) for _, s, a in points("quarter")],
            [("1", "1"), ("1", "2"), ("1", "3"), ("1", "4"),
             ("2", "1"), ("2", "2"), ("2", "3"), ("3", "1")],
        )
        self.assertEqual(points("manzil"), [("1", "1", "1")])
        self.assertEqual(points("ruku"), [("1", "1", "1"), ("2", "2", "1"), ("3", "3", "1")])
        self.assertEqual(
            points("page"),
            [("1", "1", "1"), ("2", "1", "4"), ("3", "2", "2"), ("4", "3", "1")],
        )
        self.assertEqual(
            re.findall(r'<sajda index="(\d+)" sura="(\d+)" aya="(\d+)" type="(\w+)"', self.xml),
            [("1", "1", "2", "recommended"), ("2", "2", "3", "obligatory")],
        )

    def test_variants_through_parameters(self):
        xml = synthetic_source.synthetic_metadata_xml(pages=((1, 1),)).decode("utf-8")
        self.assertEqual(xml.count("<page "), 1)

    def test_holds_no_reference_tab_carriage_return_or_bom(self):
        for forbidden in ("&", "\t", "\r", "\ufeff"):
            self.assertNotIn(forbidden, self.xml)


class MarkTableTest(unittest.TestCase):
    def test_lists_the_four_marks(self):
        self.assertEqual(
            json.loads(synthetic_source.synthetic_mark_table().decode("utf-8")),
            {"code_points": ["U+06D6", "U+06D7", "U+06DA", "U+06E9"]},
        )


if __name__ == "__main__":
    unittest.main()
