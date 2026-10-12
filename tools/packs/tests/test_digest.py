from __future__ import annotations

import hashlib
import os
import tempfile
import unittest

from hqpack.digest import sha256_bytes, sha256_file, surah_digest

# The test vectors of docs/CONTENT_PACKS.md, "Surah digest". Synthetic text,
# written with escapes so that no editor can recompose e + U+0301.
_A = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"
_DECOMPOSED = ["Synthetic ayah one", "Synthetic e\u0301 two", " " + _A + "  "]
_PRECOMPOSED = ["Synthetic ayah one", "Synthetic \u00e9 two", " " + _A + "  "]
_BASMALA = "Synthetic opening line"


def _fields(ayat, basmala=None):
    fields = [] if basmala is None else [(0, basmala.encode("utf-8"))]
    fields += [(n, text.encode("utf-8")) for n, text in enumerate(ayat, 1)]
    return fields


class SurahDigestTest(unittest.TestCase):
    def test_decomposed_with_basmala(self):
        self.assertEqual(
            surah_digest(_fields(_DECOMPOSED, _BASMALA)),
            "881415c778b801345a189d02c780cfc9d52a5f92e4390af1e176e02c12b73bb8",
        )

    def test_decomposed_without_basmala(self):
        self.assertEqual(
            surah_digest(_fields(_DECOMPOSED)),
            "1e0042fff89902b157ace9af9ce04a42b5059b3babd38e73e803480413d8051c",
        )

    def test_precomposed_with_basmala(self):
        self.assertEqual(
            surah_digest(_fields(_PRECOMPOSED, _BASMALA)),
            "3e93c75c683b8258ecc0e2698acd10f06c07c025ac7dada60a691f8e46edf177",
        )

    def test_precomposed_without_basmala(self):
        self.assertEqual(
            surah_digest(_fields(_PRECOMPOSED)),
            "0b1fede8d41e15b1529f9a121f4a57a590759dd23159e12b707d840cc68816cb",
        )

    def test_an_empty_basmala_counts(self):
        self.assertNotEqual(
            surah_digest(_fields(_DECOMPOSED, "")),
            surah_digest(_fields(_DECOMPOSED)),
        )

    def test_field_boundaries_are_part_of_the_digest(self):
        self.assertNotEqual(
            surah_digest([(1, b"ab"), (2, b"c")]),
            surah_digest([(1, b"a"), (2, b"bc")]),
        )


class FileHashTest(unittest.TestCase):
    def test_bytes_and_streamed_file_agree(self):
        data = bytes(range(256)) * 1000
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "data.bin")
            with open(path, "wb") as f:
                f.write(data)
            self.assertEqual(sha256_file(path), hashlib.sha256(data).hexdigest())
        self.assertEqual(sha256_bytes(data), hashlib.sha256(data).hexdigest())

    def test_empty_input(self):
        self.assertEqual(
            sha256_bytes(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        )


if __name__ == "__main__":
    unittest.main()
