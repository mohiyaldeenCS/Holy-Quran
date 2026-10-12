"""Synthetic sources with one change each, for the build and CLI tests."""

import json
import shutil
import tempfile
import unittest
from pathlib import Path

import synthetic_source as synthetic

REPO = Path(__file__).resolve().parents[3]
FONT = REPO / "assets" / "fonts" / "AmiriQuran-Regular.ttf"
OTHER_FONT = REPO / "assets" / "fonts" / "IBMPlexSansArabic-Regular.ttf"


def surahs_with_ayah(surah, ayah, text):
    """SYNTHETIC_SURAHS with ayah `surah:ayah` (from 1) replaced by `text`."""
    surahs = [list(s) for s in synthetic.SYNTHETIC_SURAHS]
    ayat = list(surahs[surah - 1][2])
    ayat[ayah - 1] = text
    surahs[surah - 1][2] = tuple(ayat)
    return [tuple(s) for s in surahs]


def surahs_with_basmala(surah, basmala):
    surahs = [list(s) for s in synthetic.SYNTHETIC_SURAHS]
    surahs[surah - 1][1] = basmala
    return [tuple(s) for s in surahs]


def suras_with(index, **fields):
    """SYNTHETIC_SURAS with fields of surah `index` replaced."""
    names = ("ayas", "start", "name", "tname", "ename", "type", "order", "rukus")
    suras = [dict(zip(names, s)) for s in synthetic.SYNTHETIC_SURAS]
    suras[index - 1].update(fields)
    return [tuple(s[n] for n in names) for s in suras]


class BuildCase(unittest.TestCase):
    """A temporary source directory and output directory per test."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack test "))
        self.addCleanup(shutil.rmtree, str(self.work), True)
        self.source = self.work / "source"
        self.out = self.work / "out"

    def write_source(self, text_xml=None, metadata_xml=None, mark_table=None, **overrides):
        return synthetic.write_synthetic_source(
            self.source, text_xml=text_xml, metadata_xml=metadata_xml, mark_table=mark_table, **overrides
        )

    def edit_config(self, config, change):
        data = json.loads(config.read_text(encoding="utf-8"))
        change(data)
        config.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return config

    def assert_out_empty(self):
        left = sorted(p.name for p in self.out.iterdir()) if self.out.exists() else []
        self.assertEqual(left, [], "the failed build left %s behind" % left)

    def assert_safe_message(self, message):
        self.assertTrue(message.isascii(), message)
        self.assertNotIn("Synthetic", message)
        for _, _, ayat in synthetic.SYNTHETIC_SURAHS:
            for ayah in ayat:
                for token in ayah.split(" "):
                    if token and not token.isascii():
                        self.assertNotIn(token, message)
