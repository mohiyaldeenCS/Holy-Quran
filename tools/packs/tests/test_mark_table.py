import json
import unittest

from hqpack.errors import PackError
from hqpack.mark_table import read_mark_table


def table(entries):
    return json.dumps({"code_points": entries}).encode("utf-8")


class ReadMarkTableTest(unittest.TestCase):
    def test_reads_code_points(self):
        result = read_mark_table(table(["U+06D6", "U+06E9", "U+1F600", "U+10FFFD"]))
        self.assertEqual(result, frozenset({0x06D6, 0x06E9, 0x1F600, 0x10FFFD}))
        self.assertIsInstance(result, frozenset)

    def test_accepts_white_space_in_json(self):
        data = b'{\n  "code_points": [\n    "U+06D6"\n  ]\n}\n'
        self.assertEqual(read_mark_table(data), frozenset({0x06D6}))

    def assertRefused(self, data, *parts):
        with self.assertRaises(PackError) as caught:
            read_mark_table(data)
        message = str(caught.exception)
        message.encode("ascii")
        for part in parts:
            self.assertIn(part, message)

    def test_refuses_bom(self):
        self.assertRefused(b"\xef\xbb\xbf" + table(["U+06D6"]), "byte order mark")

    def test_refuses_malformed_utf8(self):
        self.assertRefused(b'{"code_points": ["U+06D6"], "\xff": 1}', "not UTF-8", "byte 29")

    def test_refuses_utf16(self):
        self.assertRefused('{"code_points": ["U+06D6"]}'.encode("utf-16"))

    def test_refuses_malformed_json(self):
        self.assertRefused(b'{"code_points": ["U+06D6",]}', "not JSON")
        self.assertRefused(b"", "not JSON")

    def test_refuses_duplicate_keys(self):
        self.assertRefused(
            b'{"code_points": ["U+06D6"], "code_points": ["U+06D7"]}', "repeats a key"
        )

    def test_refuses_other_shapes(self):
        for data in (
            b'["U+06D6"]',
            b"{}",
            b'{"code_points": ["U+06D6"], "note": "x"}',
            b'{"marks": ["U+06D6"]}',
        ):
            with self.subTest(data=data):
                self.assertRefused(data, "one key")

    def test_refuses_empty_or_non_list(self):
        self.assertRefused(table([]), "non-empty list")
        self.assertRefused(b'{"code_points": "U+06D6"}', "non-empty list")
        self.assertRefused(b'{"code_points": null}', "non-empty list")

    def test_refuses_badly_written_entries(self):
        for index, entry in enumerate(
            ["u+06D6", "U+06d6", "U+6D6", "06D6", "U+06D6 ", " U+06D6", "U+0006D6X",
             "U+1234567", "\\u06d6", "U+06D6\n"]
        ):
            with self.subTest(entry=entry):
                self.assertRefused(table(["U+0021", entry]), "entry 1", "hex digits")
        self.assertRefused(table([1750]), "entry 0", "hex digits")
        self.assertRefused(table([None]), "entry 0", "hex digits")

    def test_refuses_needless_leading_zero(self):
        self.assertRefused(table(["U+006D6"]), "entry 0", "U+06D6")
        self.assertRefused(table(["U+01F600"]), "entry 0", "U+1F600")

    def test_refuses_beyond_unicode(self):
        self.assertRefused(table(["U+110000"]), "entry 0", "U+10FFFF")

    def test_refuses_surrogate(self):
        self.assertRefused(table(["U+D800"]), "entry 0", "U+D800", "surrogate")

    def test_refuses_unsorted_and_duplicate(self):
        self.assertRefused(table(["U+06D7", "U+06D6"]), "entry 1", "ascending")
        self.assertRefused(table(["U+06D6", "U+06D6"]), "entry 1", "ascending")

    def test_refuses_letters(self):
        for entry in ("U+0041", "U+0646", "U+0640", "U+06E5", "U+06E6"):
            with self.subTest(entry=entry):
                self.assertRefused(table([entry]), entry, "letter")

    def test_refuses_separators_and_controls(self):
        for entry in ("U+0009", "U+000A", "U+0020", "U+00A0", "U+2028", "U+2029", "U+3000"):
            with self.subTest(entry=entry):
                self.assertRefused(table([entry]), entry, "category")


if __name__ == "__main__":
    unittest.main()
