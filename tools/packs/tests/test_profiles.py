import unittest
from unittest import mock

from hqpack.errors import PackError
from hqpack.profiles import DIVISION_KINDS, PROFILES, UNAPPROVED_ID_PREFIX, profile_for


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


class UnapprovedTestCopyTest(unittest.TestCase):
    def test_the_prefix_is_fixed(self):
        self.assertEqual(UNAPPROVED_ID_PREFIX, "unapproved-")

    def test_a_hafs_id_with_the_prefix_gets_the_hafs_profile(self):
        profile = profile_for("hafs", "unapproved-hafs-tanzil", unapproved=True)
        self.assertIs(profile, PROFILES["hafs"])
        self.assertTrue(profile.needs_kfgqpc_comparison)

    def test_the_flag_is_refused_without_the_prefix(self):
        with self.assertRaisesRegex(PackError, "exactly when it is built as an unapproved test copy"):
            profile_for("hafs", "base-hafs-tanzil", unapproved=True)

    def test_the_prefix_is_refused_without_the_flag(self):
        with self.assertRaisesRegex(PackError, "exactly when it is built as an unapproved test copy"):
            profile_for("hafs", "unapproved-hafs-tanzil")
        with self.assertRaisesRegex(PackError, "exactly when its riwaya is synthetic"):
            profile_for("synthetic", "unapproved-text")

    def test_the_flag_is_refused_for_any_riwaya_but_hafs(self):
        with self.assertRaisesRegex(PackError, "hafs only, not synthetic"):
            profile_for("synthetic", "synthetic-text", unapproved=True)
        with mock.patch.dict(PROFILES, {"warsh": PROFILES["hafs"]}):
            with self.assertRaisesRegex(PackError, "hafs only, not warsh"):
                profile_for("warsh", "unapproved-warsh", unapproved=True)

    def test_a_riwaya_without_profile_stays_refused_with_the_flag(self):
        with self.assertRaisesRegex(PackError, "riwaya warsh has no profile"):
            profile_for("warsh", "unapproved-warsh", unapproved=True)

    def test_synthetic_profiles_are_unchanged(self):
        synthetic = profile_for("synthetic", "synthetic-text")
        self.assertIs(synthetic, PROFILES["synthetic"])
        self.assertEqual((synthetic.surahs, synthetic.ayat), (3, 8))


if __name__ == "__main__":
    unittest.main()
