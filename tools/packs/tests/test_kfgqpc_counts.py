"""The P5 reference counts, derived from a synthetic KFGQPC-shaped file alone."""

import dataclasses
import hashlib
import json
import unittest

from hqpack.errors import PackError
from hqpack.kfgqpc_counts import encode_counts, kfgqpc_counts
from hqpack.profiles import PROFILES

from tests.build_support import BuildCase

DATE = "2026-11-06"


class KfgqpcCountsTest(BuildCase):
    def test_counts_per_surah_and_total(self):
        path = self.write_kfgqpc()
        counts = kfgqpc_counts(path, DATE, PROFILES["synthetic"])
        self.assertEqual(
            json.loads(encode_counts(counts)),
            {
                "kfgqpc_file": {
                    "registry_row": 2,
                    "name": "hafsData_v2-0.json",
                    "version": "2.0 (update 13.0)",
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                },
                "date": DATE,
                "surahs": {"1": 4, "2": 3, "3": 1},
                "total": 8,
            },
        )

    def test_the_bytes_are_ascii_and_deterministic(self):
        path = self.write_kfgqpc()
        first = encode_counts(kfgqpc_counts(path, DATE, PROFILES["synthetic"]))
        self.assertTrue(first.isascii())
        self.assertTrue(first.endswith(b"}\n"))
        self.assertEqual(first, encode_counts(kfgqpc_counts(path, DATE, PROFILES["synthetic"])))

    def test_another_surah_count(self):
        profile = dataclasses.replace(PROFILES["synthetic"], surahs=4)
        with self.assertRaisesRegex(PackError, "the file has 3 surahs, not 4"):
            kfgqpc_counts(self.write_kfgqpc(), DATE, profile)

    def test_another_ayah_count(self):
        with self.assertRaisesRegex(PackError, "holds 8 entries, not 6236"):
            kfgqpc_counts(self.write_kfgqpc(), DATE, PROFILES["hafs"])

    def test_a_date_that_is_not_a_day(self):
        for date in ("2026-13-01", "2026-02-30", "26-11-06", "2026-11-06 "):
            with self.subTest(date=date):
                with self.assertRaises(PackError):
                    kfgqpc_counts(self.write_kfgqpc(), date, PROFILES["synthetic"])

    def test_a_file_under_another_name(self):
        path = self.write_kfgqpc()
        other = path.with_name("hafsData.json")
        path.rename(other)
        with self.assertRaisesRegex(PackError, "not hafsData_v2-0.json as published"):
            kfgqpc_counts(other, DATE, PROFILES["synthetic"])


if __name__ == "__main__":
    unittest.main()
