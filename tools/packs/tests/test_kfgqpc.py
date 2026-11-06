"""The strict reader of KFGQPC's hafsData JSON, on synthetic KFGQPC-shaped files."""

import json
import shutil
import tempfile
import unittest
from pathlib import Path

import synthetic_source as synthetic
from hqpack.errors import PackError
from hqpack.kfgqpc import read_kfgqpc, read_kfgqpc_file

AYAT = 8
BOM = b"\xef\xbb\xbf"


def _json(entries):
    return json.dumps(entries, ensure_ascii=False).encode("utf-8")


class KfgqpcReaderTest(unittest.TestCase):
    def assert_refused(self, pattern, data, ayat=AYAT):
        with self.assertRaises(PackError) as caught:
            read_kfgqpc(data, ayat)
        message = str(caught.exception)
        self.assertRegex(message, pattern)
        self.assertTrue(message.isascii(), message)
        self.assertNotIn("Synthetic", message)
        return message

    def entries(self):
        return synthetic.synthetic_kfgqpc_entries()

    def test_reads_the_synthetic_file(self):
        # The published file's first bytes are 5B 0A 09: no BOM.
        self.assertTrue(synthetic.synthetic_kfgqpc_json().startswith(b"[\n\t"))
        ayat = read_kfgqpc(synthetic.synthetic_kfgqpc_json(), AYAT)
        self.assertEqual(
            [(a.id, a.surah, a.number, a.juz, a.page) for a in ayat],
            [
                (1, 1, 1, 1, 1), (2, 1, 2, 1, 1), (3, 1, 3, 1, 1), (4, 1, 4, 1, 2),
                (5, 2, 1, 2, 2), (6, 2, 2, 2, 3), (7, 2, 3, 2, 3), (8, 3, 1, 2, 4),
            ],
        )
        entries = self.entries()
        self.assertEqual([a.text for a in ayat], [e["aya_text"] for e in entries])

    def test_the_text_is_kept_as_given(self):
        entries = self.entries()
        # Canonically equivalent to the order U+064E U+0651; a normaliser would reorder it.
        entries[0]["aya_text"] = "x\u0651\u064e\u00a0\ufc00"
        ayat = read_kfgqpc(_json(entries), AYAT)
        self.assertEqual(ayat[0].text, "x\u0651\u064e\u00a0\ufc00")

    def test_a_bom_is_refused(self):
        # The CSV is published with a BOM, the JSON without one.
        self.assert_refused("begins with a UTF-8 BOM, which the published file does not", BOM + synthetic.synthetic_kfgqpc_json())

    def test_malformed_utf8(self):
        self.assert_refused(r"malformed UTF-8 at byte 1", b"[\xff]")

    def test_invalid_json(self):
        self.assert_refused(r"invalid JSON at line 1 column \d+", b"[{]")
        self.assert_refused("invalid JSON", b"[] []")

    def test_not_an_array(self):
        self.assert_refused("not an array", b"{}")

    def test_another_number_of_entries(self):
        self.assert_refused("holds 8 entries, not 9", synthetic.synthetic_kfgqpc_json(), ayat=9)

    def test_a_missing_id(self):
        entries = self.entries()
        del entries[2]
        self.assert_refused("entry 3 has id 4, not 3", _json(entries), ayat=7)
        entries = self.entries()
        del entries[2]["id"]
        self.assert_refused("entry 3 lacks field id", _json(entries))

    def test_ids_out_of_order(self):
        entries = self.entries()
        entries[1], entries[2] = entries[2], entries[1]
        self.assert_refused("entry 2 has id 3", _json(entries))

    def test_a_duplicate_address(self):
        entries = self.entries()
        entries[2]["aya_no"] = 2
        self.assert_refused(r"id 3 is 1:2, which does not follow 1:2", _json(entries))

    def test_a_skipped_ayah_or_surah(self):
        entries = self.entries()
        entries[2]["aya_no"] = 4
        self.assert_refused(r"id 3 is 1:4, which does not follow 1:2", _json(entries))
        entries = self.entries()
        entries[0]["sura_no"] = 2
        self.assert_refused(r"id 1 is 2:1, which does not follow 0:0", _json(entries))

    def test_wrong_types(self):
        for field, value, pattern in (
            ("id", "1", "entry 1 lacks|field id is not an integer"),
            ("page", 1.0, "id 1: field page is not an integer"),
            ("jozz", True, "id 1: field jozz is not an integer"),
            ("line_end", None, "id 1: field line_end is not an integer"),
            ("aya_text", 5, "id 1: field aya_text is not a string"),
            ("sura_name_ar", ["x"], "id 1: field sura_name_ar is not a string"),
            ("aya_text_emlaey", None, "id 1: field aya_text_emlaey is not a string"),
        ):
            with self.subTest(field=field):
                entries = self.entries()
                entries[0][field] = value
                self.assert_refused(pattern, _json(entries))

    def test_a_number_below_one(self):
        entries = self.entries()
        entries[4]["page"] = 0
        self.assert_refused("id 5: field page is 0, below 1", _json(entries))

    def test_an_empty_ayah(self):
        entries = self.entries()
        entries[4]["aya_text"] = ""
        self.assert_refused("id 5: field aya_text is empty", _json(entries))

    def test_an_unknown_or_missing_field(self):
        entries = self.entries()
        entries[4]["\u0646"] = 1
        message = self.assert_refused("id 5 has a field other than the columns", _json(entries))
        self.assertNotIn("\u0646", message)
        entries = self.entries()
        del entries[4]["page"]
        self.assert_refused("id 5 lacks field page", _json(entries))

    def test_a_repeated_field(self):
        data = synthetic.synthetic_kfgqpc_json().replace(b'"page": 1,', b'"page": 1, "page": 1,', 1)
        self.assert_refused("repeats a field name", data)

    def test_a_non_json_constant(self):
        data = synthetic.synthetic_kfgqpc_json().replace(b'"page": 1,', b'"page": NaN,', 1)
        self.assert_refused("NaN, which is not JSON", data)

    def test_a_lone_surrogate(self):
        data = synthetic.synthetic_kfgqpc_json().replace(b'"aya_text_emlaey": "', b'"aya_text_emlaey": "\\ud800', 1)
        self.assert_refused("id 1: field aya_text_emlaey holds a lone surrogate at index 0", data)

    def test_an_entry_that_is_not_an_object(self):
        entries = self.entries()
        entries[3] = [1]
        self.assert_refused("entry 4 is not an object", _json(entries))


class KfgqpcFileTest(unittest.TestCase):
    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack kfgqpc "))
        self.addCleanup(shutil.rmtree, str(self.work), True)

    def test_the_file_with_its_published_name(self):
        path = self.work / synthetic.KFGQPC_FILE
        path.write_bytes(synthetic.synthetic_kfgqpc_json())
        ayat, sha256 = read_kfgqpc_file(path, AYAT)
        self.assertEqual(len(ayat), AYAT)
        self.assertRegex(sha256, "^[0-9a-f]{64}$")

    def test_another_name(self):
        path = self.work / "hafsData_v2-0 \u0646.json"
        path.write_bytes(synthetic.synthetic_kfgqpc_json())
        with self.assertRaises(PackError) as caught:
            read_kfgqpc_file(path, AYAT)
        message = str(caught.exception)
        self.assertIn("U+0646", message)
        self.assertIn("not hafsData_v2-0.json", message)
        self.assertTrue(message.isascii())


if __name__ == "__main__":
    unittest.main()
