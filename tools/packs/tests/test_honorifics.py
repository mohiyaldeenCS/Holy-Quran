"""D-188: the honorific table and each of its refusals, on a synthetic table."""

from __future__ import annotations

import copy
import hashlib
import json
import unittest

from hqpack.errors import PackError
from hqpack.honorifics import read_honorific_table
from tests.ziydia_factory import HONORIFIC, TABLE


def encode(table):
    return json.dumps(table, ensure_ascii=False).encode("utf-8")


class HonorificTableTest(unittest.TestCase):
    def test_reads_an_approved_table(self):
        data = encode(TABLE)
        table = read_honorific_table(data)
        self.assertEqual(table.phrases, {"\u00f7": HONORIFIC, "&": "Synthetic honorific"})
        self.assertEqual((table.version, table.approved_by, table.approved_on), (1, "Synthetic approver", "2026-01-02"))
        self.assertEqual(table.derived_from_font_sha256, "a" * 64)
        self.assertEqual(table.sha256, hashlib.sha256(data).hexdigest())

    def test_refusals(self):
        def drop(key):
            return lambda t: t.pop(key)

        def code(index, **fields):
            return lambda t: t["codes"][index].update(fields)

        cases = (
            (drop("approved_by"), "approved_by is missing"),
            (drop("approved_on"), "approved_on is missing"),
            (lambda t: t.update(approved_by=None), "approved_by is missing, so the table is not approved"),
            (lambda t: t.update(approved_on=""), "approved_on is missing, so the table is not approved"),
            (lambda t: t.update(approved_on="2026-02-30"), "approved_on must be a real date"),
            (lambda t: t.update(approved_by=" Synthetic"), "approved_by has spaces at its edges"),
            (lambda t: t.update(extra=1), "has an unknown key extra"),
            (code(0, extra=1), "codes[0] has an unknown key extra"),
            (lambda t: t["codes"][0].pop("phrase"), "codes[0].phrase is missing"),
            (lambda t: t.update(version=0), "version must be a positive integer"),
            (lambda t: t.update(derived_from_font_sha256="A" * 64), "derived_from_font_sha256 must be lowercase hex"),
            (lambda t: t.update(codes=[]), "codes must be a non-empty list"),
            (code(0, code="U+00F7U+00F8"), "codes[0].code is not one character written U+XXXX"),
            (code(0, code="\u00f7"), "codes[0].code is not one character written U+XXXX"),
            (code(0, code="U+f7"), "codes[0].code is not one character written U+XXXX"),
            (code(0, code="U+D800"), "codes[0].code is not a Unicode scalar value"),
            (code(1, code="U+00F7"), "codes[1].code U+00F7 repeats"),
            (code(0, code="U+FDFA"), "codes[0].code U+FDFA is markup, white space"),
            (code(0, code="U+002E"), "codes[0].code U+002E is markup, white space"),
            (code(0, code="U+003C"), "codes[0].code U+003C is markup, white space"),
            (code(0, code="U+0020"), "codes[0].code U+0020 is markup, white space"),
            (code(0, phrase=""), "codes[0].phrase is empty"),
            (code(0, phrase=" Synthetic"), "codes[0].phrase has spaces at its edges"),
            (code(0, phrase="Synthetic\u00a0"), "codes[0].phrase has spaces at its edges"),
            (code(0, phrase="Synthetic <b>"), "codes[0].phrase holds U+003C"),
            (code(0, phrase="Synthetic >"), "codes[0].phrase holds U+003E"),
            (code(0, phrase="Synthetic & more"), "codes[0].phrase holds U+0026"),
            (code(0, phrase="Synthetic\u001fline"), "codes[0].phrase holds U+001F"),
            (code(0, phrase="Synthetic\nline"), "codes[0].phrase holds white space other than single U+0020 characters"),
            (code(0, phrase="Synthetic\tline"), "codes[0].phrase holds white space other than single U+0020 characters"),
            (code(0, phrase="Synthetic  line"), "codes[0].phrase holds white space other than single U+0020 characters"),
            (code(0, phrase="Synthetic \u000bline"), "codes[0].phrase holds white space other than single U+0020"),
            (code(0, code="U+064B"), "codes[0].code U+064B is a combining mark"),
            (code(0, code="U+0301"), "codes[0].code U+0301 is a combining mark"),
            (code(1, phrase="Synthetic \u00f7"), "the phrase of U+0026 holds the code U+00F7"),
        )
        for change, expected in cases:
            with self.subTest(expected=expected):
                table = copy.deepcopy(TABLE)
                change(table)
                with self.assertRaises(PackError) as caught:
                    read_honorific_table(encode(table))
                self.assertIn(expected, str(caught.exception))
                self.assertTrue(str(caught.exception).startswith("honorific table: "))
                self.assertNotIn("Synthetic", str(caught.exception))

    def test_a_phrase_with_single_spaces_and_a_letter_code_are_kept(self):
        # The site's own codes include letters (U+00AA, U+00C0, U+00F8), so a letter is a code.
        table = copy.deepcopy(TABLE)
        table["codes"][0].update(code="U+00F8", phrase="Synthetic phrase \u00a0 of words")
        self.assertEqual(read_honorific_table(encode(table)).phrases["\u00f8"], "Synthetic phrase \u00a0 of words")

    def test_refuses_what_is_not_strict_json(self):
        cases = (
            (b"\xef\xbb\xbf" + encode(TABLE), "byte order mark"),
            (encode(TABLE).replace(b'"version": 1', b'"version": 1, "version": 1'), "a repeated key version"),
            (b"\xff", "not UTF-8 at byte 0"),
            (b"[]", "the table is not an object"),
            (encode(TABLE).replace(b'"version": 1', b'"version": NaN'), "NaN is not a JSON number"),
        )
        for data, expected in cases:
            with self.subTest(expected=expected):
                with self.assertRaisesRegex(PackError, expected):
                    read_honorific_table(data)


if __name__ == "__main__":
    unittest.main()
