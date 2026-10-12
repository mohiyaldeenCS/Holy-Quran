from __future__ import annotations

import json
import unittest

from hqpack.errors import PackError
from hqpack.manifest import build_manifest, encode_manifest, source_entry

_HASH = "0" * 64
# A synthetic notice in Arabic script, plainly not Quran text.
_NOTICE = "Synthetic notice \u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"


def _licence(**changes):
    licence = {
        "allows_export": True,
        "notice": _NOTICE,
        "permission_ref": None,
        "text": "Synthetic licence",
    }
    licence.update(changes)
    return licence


def _source(role="text", registry_row=1, options=None, licence=None):
    return source_entry(
        role=role,
        registry_row=registry_row,
        name="Synthetic source",
        publisher="Synthetic publisher",
        url="https://example.invalid/synthetic",
        version="1.0",
        fetched_on="2026-01-01",
        file_sha256=_HASH,
        trust_grade="A",
        options=options,
        licence=licence or _licence(),
    )


def _manifest(**changes):
    arguments = dict(
        pack_id="synthetic-text",
        version=1,
        changelog=[{"summary": "Synthetic", "date": "2026-01-01", "version": 1}],
        riwaya="hafs",
        edition="synthetic-edition",
        font={"sha256": _HASH, "version": "1.003", "family": "Synthetic Font"},
        sources=[
            _source(options={"synthetic_type": "plain", "synthetic_marks": True, "level": 2}),
            _source("edition_map", 4),
        ],
        text_sha256="1" * 64,
        text_bytes=4096,
        surah_sha256={2: "b" * 64, 10: "c" * 64, 1: "a" * 64}
        | {n: "d" * 64 for n in range(3, 10)},
        counts={
            "sajdas": 2,
            "divisions": {"page": 4, "rub": 8, "hizb": 4, "juz": 2},
            "marks": 3,
            "words": 20,
            "ayat": 8,
            "surahs": 10,
        },
        reviews=[{"scope": "synthetic", "date": "2026-01-02", "reviewer": "synthetic reviewer"}],
    )
    arguments.update(changes)
    return build_manifest(**arguments)


class KeyOrderTest(unittest.TestCase):
    def setUp(self):
        self.manifest = _manifest()

    def test_top_level(self):
        self.assertEqual(
            list(self.manifest),
            [
                "format",
                "format_version",
                "id",
                "kind",
                "version",
                "changelog",
                "riwaya",
                "edition",
                "font",
                "sources",
                "files",
                "surah_sha256",
                "counts",
                "reviews",
            ],
        )
        self.assertEqual(self.manifest["format"], "holyquran-pack")
        self.assertEqual(self.manifest["format_version"], 1)
        self.assertEqual(self.manifest["kind"], "text")

    def test_nested_objects(self):
        m = self.manifest
        self.assertEqual(list(m["changelog"][0]), ["version", "date", "summary"])
        self.assertEqual(list(m["font"]), ["family", "version", "sha256"])
        self.assertEqual(
            list(m["sources"][0]),
            [
                "role",
                "registry_row",
                "name",
                "publisher",
                "url",
                "version",
                "fetched_on",
                "file_sha256",
                "trust_grade",
                "options",
                "licence",
            ],
        )
        self.assertEqual(
            list(m["sources"][0]["licence"]),
            ["text", "permission_ref", "notice", "allows_export"],
        )
        self.assertEqual(m["files"], [{"name": "text.sqlite", "sha256": "1" * 64, "bytes": 4096}])
        self.assertEqual(list(m["files"][0]), ["name", "sha256", "bytes"])
        self.assertEqual(
            list(m["counts"]), ["surahs", "ayat", "words", "marks", "divisions", "sajdas"]
        )
        self.assertEqual(list(m["counts"]["divisions"]), ["juz", "hizb", "rub", "page"])
        self.assertEqual(list(m["reviews"][0]), ["reviewer", "date", "scope"])

    def test_options_keep_the_source_order(self):
        self.assertEqual(
            list(self.manifest["sources"][0]["options"]),
            ["synthetic_type", "synthetic_marks", "level"],
        )
        self.assertIsNone(self.manifest["sources"][1]["options"])

    def test_surah_digests_are_keyed_in_numeric_order(self):
        self.assertEqual(
            list(self.manifest["surah_sha256"]), [str(n) for n in range(1, 11)]
        )
        self.assertEqual(self.manifest["surah_sha256"]["10"], "c" * 64)

    def test_string_surah_keys_are_accepted(self):
        m = _manifest(
            surah_sha256={"2": "b" * 64, "1": "a" * 64},
            counts=dict(_manifest()["counts"], surahs=2),
        )
        self.assertEqual(list(m["surah_sha256"]), ["1", "2"])


class ManifestRefusalTest(unittest.TestCase):
    def test_surah_digests_must_cover_one_to_n(self):
        with self.assertRaises(PackError):
            _manifest(surah_sha256={1: _HASH, 3: _HASH}, counts=dict(_manifest()["counts"], surahs=2))
        with self.assertRaises(PackError):
            _manifest(surah_sha256={1: _HASH, "1": _HASH}, counts=dict(_manifest()["counts"], surahs=1))
        with self.assertRaises(PackError):
            _manifest(surah_sha256={"01": _HASH}, counts=dict(_manifest()["counts"], surahs=1))

    def test_a_missing_or_unknown_field_is_refused(self):
        with self.assertRaises(PackError):
            _manifest(font={"family": "Synthetic Font", "version": "1.003"})
        with self.assertRaises(PackError):
            _manifest(reviews=[{"reviewer": "r", "date": "2026-01-01", "scope": "s", "extra": 1}])

    def test_empty_options_are_refused(self):
        with self.assertRaises(PackError):
            _source(options={})
        with self.assertRaises(PackError):
            _source(options={"": "synthetic"})

    def test_a_licence_needs_text_or_permission(self):
        with self.assertRaises(PackError):
            _source(licence=_licence(text=None, permission_ref=None))


class EncodeTest(unittest.TestCase):
    def setUp(self):
        self.manifest = _manifest()
        self.data = encode_manifest(self.manifest)

    def test_round_trip(self):
        self.assertEqual(json.loads(self.data.decode("utf-8")), self.manifest)

    def test_round_trip_keeps_key_order(self):
        decoded = json.loads(self.data.decode("utf-8"))
        self.assertEqual(list(decoded), list(self.manifest))
        self.assertEqual(list(decoded["surah_sha256"]), list(self.manifest["surah_sha256"]))

    def test_framing(self):
        self.assertTrue(self.data.startswith(b"{"))
        self.assertTrue(self.data.endswith(b"}\n"))
        self.assertFalse(self.data.startswith(b"\xef\xbb\xbf"))
        self.assertIn(b'\n  "format": "holyquran-pack",\n', self.data)
        self.assertNotIn(b" \n", self.data)

    def test_non_ascii_is_written_as_utf8(self):
        self.assertIn(_NOTICE.encode("utf-8"), self.data)
        self.assertNotIn(b"\\u0646", self.data)

    def test_deterministic(self):
        self.assertEqual(encode_manifest(_manifest()), self.data)

    def test_a_float_is_refused_anywhere(self):
        with self.assertRaises(PackError) as caught:
            encode_manifest(_manifest(text_bytes=1.0))
        self.assertIn("manifest.files[0].bytes", str(caught.exception))
        with self.assertRaises(PackError):
            encode_manifest(_manifest(sources=[_source(options={"level": 1.5})]))
        with self.assertRaises(PackError):
            encode_manifest({"value": float("nan")})

    def test_a_leading_byte_order_mark_is_refused(self):
        with self.assertRaises(PackError) as caught:
            encode_manifest(_manifest(edition="\ufeffsynthetic"))
        self.assertIn("manifest.edition begins with U+FEFF", str(caught.exception))
        with self.assertRaises(PackError):
            encode_manifest({"\ufeffkey": 1})

    def test_a_lone_surrogate_is_refused(self):
        with self.assertRaises(PackError) as caught:
            encode_manifest(_manifest(sources=[_source(licence=_licence(notice="ab\udc00"))]))
        self.assertIn("sources[0].licence.notice", str(caught.exception))

    def test_a_non_json_value_is_refused(self):
        with self.assertRaises(PackError):
            encode_manifest({"value": b"bytes"})


if __name__ == "__main__":
    unittest.main()
