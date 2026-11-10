"""The P5 counts read back strictly, from a file kfgqpc-counts wrote over a synthetic KFGQPC-shaped file."""

import json
import unittest

from hqpack.ayah_counts import read_ayah_counts
from hqpack.errors import PackError
from hqpack.kfgqpc_counts import encode_counts, kfgqpc_counts
from hqpack.profiles import PROFILES

from tests.build_support import BuildCase


def _encoded(counts):
    return (json.dumps(counts, ensure_ascii=True, indent=2) + "\n").encode("ascii")


class AyahCountsTest(BuildCase):
    def setUp(self):
        super().setUp()
        self.counts = kfgqpc_counts(self.write_kfgqpc(), "2026-11-06", PROFILES["synthetic"])
        self.data = encode_counts(self.counts)

    def changed(self, change):
        counts = json.loads(self.data)
        change(counts)
        return _encoded(counts)

    def assert_refused(self, data, expected):
        with self.assertRaises(PackError) as caught:
            read_ayah_counts(data)
        self.assertIn(expected, str(caught.exception))

    def test_reads_what_kfgqpc_counts_writes(self):
        self.assertEqual(read_ayah_counts(self.data), {1: 4, 2: 3, 3: 1})
        self.assertEqual(list(read_ayah_counts(self.data)), [1, 2, 3])

    def test_bytes_other_than_the_writers(self):
        self.assert_refused(self.data.rstrip(b"\n"), "not as kfgqpc-counts writes them")
        self.assert_refused(json.dumps(json.loads(self.data)).encode("ascii"), "not as kfgqpc-counts writes them")
        self.assert_refused(b"\xef\xbb\xbf" + self.data, "the file is not ASCII")
        self.assert_refused(self.data.replace(b'"date"', b'"d\\u0061te"'), "not as kfgqpc-counts writes them")

    def test_not_json_or_a_repeated_key(self):
        self.assert_refused(b"{", "not JSON")
        self.assert_refused(self.data.replace(b'"total": 8', b'"total": 8.0'), "not JSON")
        self.assert_refused(self.data.replace(b'"total": 8', b'"total": NaN'), "not JSON")
        self.assert_refused(
            self.data.replace(b'"total": 8', b'"total": 8,\n  "total": 8'), "repeats a key"
        )

    def test_keys_and_their_order(self):
        def reorder(counts):
            counts["date"] = counts.pop("date")

        self.assert_refused(self.changed(reorder), "the file is not an object of kfgqpc_file, date")
        self.assert_refused(self.changed(lambda c: c.update(extra=1)), "the file is not an object")
        self.assert_refused(self.changed(lambda c: c["kfgqpc_file"].pop("version")), "kfgqpc_file is not an object")

    def test_another_kfgqpc_file(self):
        for field, value in (("registry_row", 3), ("registry_row", True), ("name", "hafsData.json"), ("version", "1.0")):
            with self.subTest(field=field, value=value):
                self.assert_refused(
                    self.changed(lambda c: c["kfgqpc_file"].update({field: value})), "kfgqpc_file is not registry row 2"
                )
        self.assert_refused(
            self.changed(lambda c: c["kfgqpc_file"].update(sha256="A" * 64)), "sha256 is not lowercase hex"
        )

    def test_a_date_that_is_not_a_day(self):
        self.assert_refused(self.changed(lambda c: c.update(date="2026-02-30")), "date is not a day")
        self.assert_refused(self.changed(lambda c: c.update(date="26-11-06")), "date is not YYYY-MM-DD")

    def test_surahs_one_to_n_with_positive_counts(self):
        self.assert_refused(self.changed(lambda c: c["surahs"].pop("2")), "surahs key 2 is not 2")
        self.assert_refused(self.changed(lambda c: c.update(surahs={"0": 8})), "surahs key 1 is not 1")
        self.assert_refused(self.changed(lambda c: c.update(surahs={})), "surahs is not a non-empty object")
        self.assert_refused(self.changed(lambda c: c["surahs"].update({"3": 0})), "surah 3's count is not a positive")
        self.assert_refused(self.changed(lambda c: c["surahs"].update({"3": True})), "surah 3's count is not a positive")

    def test_the_total_is_the_sum(self):
        self.assert_refused(self.changed(lambda c: c.update(total=9)), "total is not the sum")


if __name__ == "__main__":
    unittest.main()
