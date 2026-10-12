import unittest

from hqpack.errors import PackError
from hqpack.profiles import DIVISION_KINDS, PROFILES, profile_for


class ProfileTest(unittest.TestCase):
    def test_hafs_totals(self):
        hafs = profile_for("hafs", "base-hafs-tanzil")
        self.assertEqual((hafs.surahs, hafs.ayat), (114, 6236))
        self.assertEqual(hafs.divisions, {"juz": 30, "hizb": 60, "rub": 240, "page": 604})
        self.assertEqual(hafs.without_basmala, frozenset({1, 9}))
        self.assertTrue(hafs.needs_kfgqpc_comparison)
        self.assertEqual(hafs.forbidden_code_points, frozenset({0x06DE}))
        self.assertEqual(
            hafs.required_code_points,
            (frozenset(range(0x06D6, 0x06DC)), frozenset({0x06E9})),
        )

    def test_every_profile_names_every_division_kind(self):
        for profile in PROFILES.values():
            self.assertEqual(tuple(profile.divisions), DIVISION_KINDS)

    def test_a_riwaya_without_profile_is_refused(self):
        with self.assertRaisesRegex(PackError, "riwaya warsh has no profile"):
            profile_for("warsh", "base-warsh")

    def test_synthetic_ids_and_riwaya_go_together(self):
        self.assertFalse(profile_for("synthetic", "synthetic-text").needs_kfgqpc_comparison)
        with self.assertRaisesRegex(PackError, "exactly when its riwaya is synthetic"):
            profile_for("synthetic", "base-hafs-tanzil")
        with self.assertRaisesRegex(PackError, "exactly when its riwaya is synthetic"):
            profile_for("hafs", "synthetic-text")


if __name__ == "__main__":
    unittest.main()
