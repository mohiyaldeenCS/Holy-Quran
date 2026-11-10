"""The command line, in process and once as a script."""

import hashlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import synthetic_source as synthetic
from hqpack import cli
from hqpack.kfgqpc_counts import encode_counts, kfgqpc_counts
from hqpack.profiles import PROFILES
from hqpack.review_page import KFGQPC_FONT_NAME

from tests import tafsir_pack_factory
from tests.build_support import FONT, HAFS_ID, OTHER_FONT, TEST_COPY_ID, BuildCase, hafs_shaped_profiles
from tests.test_review_page import synthetic_kfgqpc_font

PACK_PY = Path(__file__).resolve().parents[1] / "pack.py"


def _openssl_ed25519():
    if shutil.which("openssl") is None:
        return False
    with tempfile.TemporaryDirectory() as work:
        probe = subprocess.run(
            ["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(Path(work) / "k.pem")],
            capture_output=True,
        )
    return probe.returncode == 0


class CliCase(BuildCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        code = cli.main([str(a) for a in argv], out=out, err=err)
        self.assert_safe_message(out.getvalue() + err.getvalue())
        return code, out.getvalue(), err.getvalue()

    def build(self):
        code, out, _ = self.run_cli("build", "--config", self.write_source(), "--font", FONT, "--out", self.out)
        self.assertEqual(code, 0)
        return self.out / "synthetic-text" / "1", out


class BuildAndVerifyTest(CliCase):
    def test_build_prints_counts_hashes_and_that_the_pack_is_unsigned(self):
        pack, out = self.build()
        self.assertIn("counts surahs 3 ayat 8 words 21 marks 5 sajdas 2", out)
        self.assertIn("divisions juz 2 hizb 2 rub 8 page 4", out)
        self.assertRegex(out, r"surah 3 sha256 [0-9a-f]{64}")
        self.assertIn("verified", out)
        self.assertIn("unsigned", out)
        self.assertNotIn("Synthetic", out)

    def test_verify_with_font_and_mark_table(self):
        pack, _ = self.build()
        code, out, _ = self.run_cli(
            "verify", pack, "--font", FONT, "--mark-table", self.source / "marks.json"
        )
        self.assertEqual(code, 0, out)
        self.assertIn("verified", out)
        self.assertIn("unsigned", out)

    def test_verify_reports_a_changed_byte(self):
        pack, _ = self.build()
        data = bytearray((pack / "text.sqlite").read_bytes())
        data[-1] ^= 1
        (pack / "text.sqlite").write_bytes(bytes(data))
        code, out, _ = self.run_cli("verify", pack)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("problem: ", out)

    def test_a_refused_build_exits_65(self):
        code, _, err = self.run_cli(
            "build", "--config", self.write_source(riwaya="warsh", id="base-warsh"), "--font", FONT, "--out", self.out
        )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("refused: riwaya warsh has no profile", err)

    def test_usage_errors_exit_64(self):
        self.assertEqual(self.run_cli("build", "--config", "x")[0], cli.EX_USAGE)
        self.assertEqual(self.run_cli()[0], cli.EX_USAGE)
        self.assertEqual(self.run_cli("unknown")[0], cli.EX_USAGE)

    def test_an_unexpected_error_is_printed_by_its_type_only(self):
        with mock.patch.object(cli, "build_pack", side_effect=ValueError("synthetic secret")):
            code, _, err = self.run_cli("build", "--config", "c", "--font", "f", "--out", "o")
        self.assertEqual(code, cli.EX_SOFTWARE)
        self.assertEqual(err.strip(), "failed: ValueError")

    def test_pack_py_runs_as_a_script(self):
        config = self.write_source()
        done = subprocess.run(
            [sys.executable, str(PACK_PY), "build", "--config", str(config), "--font", str(FONT), "--out", str(self.out)],
            capture_output=True,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue(done.stdout.isascii())
        self.assertTrue((self.out / "synthetic-text" / "1" / "manifest.json").is_file())


class UnapprovedTestCopyCliTest(CliCase):
    def config(self, **overrides):
        overrides.setdefault("riwaya", "hafs")
        overrides.setdefault("id", TEST_COPY_ID)
        overrides.setdefault("reviews", [])
        return self.write_source(**overrides)

    def build_copy(self, *extra):
        return self.run_cli("build", "--config", self.config(), "--font", FONT, "--out", self.out, *extra)

    def test_build_with_the_flag_says_what_it_built(self):
        with hafs_shaped_profiles():
            code, out, err = self.build_copy("--unapproved-test-copy")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("unapproved test copy: the KFGQPC comparison was not run", out)
        self.assertIn("verified", out)
        self.assertTrue((self.out / TEST_COPY_ID / "1" / "manifest.json").is_file())

    def test_build_without_the_flag_is_refused(self):
        with hafs_shaped_profiles():
            code, _, err = self.build_copy()
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("refused: id %s" % TEST_COPY_ID, err)
        self.assertFalse(self.out.exists())

    def test_the_real_hafs_profile_stays_refused_for_a_plain_build(self):
        config = self.write_source(riwaya="hafs", id="base-hafs-tanzil")
        code, _, err = self.run_cli("build", "--config", config, "--font", FONT, "--out", self.out)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("KFGQPC", err)

    def test_the_flag_with_reviews_exits_65(self):
        review = [{"reviewer": "synthetic reviewer", "date": "2026-01-01", "scope": "synthetic"}]
        with hafs_shaped_profiles():
            code, _, err = self.run_cli(
                "build", "--config", self.config(reviews=review), "--font", FONT, "--out", self.out,
                "--unapproved-test-copy",
            )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("no reviews", err)

    def test_the_flag_with_an_output_in_a_git_tree_exits_65(self):
        (self.work / "tree" / ".git").mkdir(parents=True)
        with hafs_shaped_profiles():
            code, _, err = self.run_cli(
                "build", "--config", self.config(), "--font", FONT, "--out", self.work / "tree" / "out",
                "--unapproved-test-copy",
            )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("inside a Git working tree", err)


class KfgqpcCliTest(CliCase):
    def compare(self, entries=None):
        self.write_source()
        report = self.work / "report.json"
        with hafs_shaped_profiles():
            code, out, err = self.run_cli(
                "compare",
                "--text", self.source / synthetic.TEXT_FILE,
                "--metadata", self.source / synthetic.METADATA_FILE,
                "--kfgqpc", self.write_kfgqpc(entries),
                "--table", self.write_table(),
                "--report", report,
            )
        data = report.read_bytes()
        self.assert_safe_message(data.decode("ascii"))
        return code, out, json.loads(data)

    def test_compare_passes_on_equal_texts(self):
        code, out, report = self.compare()
        self.assertEqual(code, 0, out)
        self.assertTrue(report["passed"])
        self.assertIn("no undocumented difference", out)
        self.assertIn("juz differences 0, quarter differences 0", out)
        self.assertRegex(out, r"kfgqpc sha256 [0-9a-f]{64}")
        text_sha256 = hashlib.sha256((self.source / synthetic.TEXT_FILE).read_bytes()).hexdigest()
        self.assertIn("tanzil text sha256 %s" % text_sha256, out)
        self.assertEqual(report["tanzil"]["text_sha256"], text_sha256)
        self.assertEqual(
            report["tanzil"]["metadata_sha256"],
            hashlib.sha256((self.source / synthetic.METADATA_FILE).read_bytes()).hexdigest(),
        )
        self.assertRegex(out, r"table version 2 sha256 [0-9a-f]{64}")

    def test_compare_writes_the_report_and_exits_65_on_a_difference(self):
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[3]["aya_text"] = entries[3]["aya_text"].replace("\u064e", "\u06e1")
        code, out, report = self.compare(entries)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("undocumented differences 1 in 1 patterns", out)
        self.assertEqual(out.splitlines()[-1], "problems found: the comparison fails")
        self.assertNotIn("no undocumented difference", out)
        self.assertEqual(report["differences"][0]["address"], "hafs:1:4")
        self.assertEqual(report["patterns"][0]["kfgqpc"], ["U+06E1"])

    def test_compare_needs_every_input(self):
        self.assertEqual(self.run_cli("compare", "--text", "t", "--metadata", "m", "--kfgqpc", "k", "--table", "x")[0], cli.EX_USAGE)

    def review_page(self, out):
        self.write_source()
        font = self.work / KFGQPC_FONT_NAME
        font.write_bytes(synthetic_kfgqpc_font())
        entries = synthetic.synthetic_kfgqpc_entries()
        entries[3]["aya_text"] = entries[3]["aya_text"].replace("\u064e", "\u06e1")
        with hafs_shaped_profiles():
            return self.run_cli(
                "review-page",
                "--text", self.source / synthetic.TEXT_FILE,
                "--metadata", self.source / synthetic.METADATA_FILE,
                "--kfgqpc", self.write_kfgqpc(entries),
                "--table", self.write_table(),
                "--tanzil-font", FONT,
                "--kfgqpc-font", font,
                "--out", out,
            )

    def test_review_page_writes_the_page(self):
        out = self.work / "review"
        code, printed, err = self.review_page(out)
        self.assertEqual(code, 0, err)
        lines = printed.splitlines()
        self.assertEqual(lines[0], "page %s" % (out / "review.html"))
        self.assertTrue((out / "review.html").is_file())
        text_sha256 = hashlib.sha256((self.source / synthetic.TEXT_FILE).read_bytes()).hexdigest()
        self.assertIn("tanzil text sha256 %s" % text_sha256, lines)
        self.assertIn("table version 2", lines)
        self.assertRegex(printed, r"kfgqpc font sha256 [0-9a-f]{64}")
        self.assertIn("undocumented differences 1 in 1 patterns", printed)
        self.assertIn(
            "section A places 1, section B patterns 0 (places 0), section C patterns 0 (places 0), "
            "section D rows 3 (surah-opening quarter starts 3)",
            lines,
        )
        self.assertIn("never commit or upload them", lines[-1])

    def test_review_page_refuses_a_folder_in_a_git_tree(self):
        (self.work / ".git").mkdir()
        code, _, err = self.review_page(self.work / "review")
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("refused: the output folder", err)
        self.assertIn("is inside the Git working tree", err)
        self.assertFalse((self.work / "review").exists())

    def test_review_page_needs_every_input(self):
        code, _, err = self.run_cli("review-page", "--text", "t", "--metadata", "m", "--kfgqpc", "k", "--table", "x")
        self.assertEqual(code, cli.EX_USAGE)
        self.assertIn("--tanzil-font", err)

    def test_build_of_a_hafs_pack_with_the_comparison(self):
        config = self.write_source(riwaya="hafs", id=HAFS_ID)
        with hafs_shaped_profiles():
            code, _, err = self.run_cli(
                "build", "--config", config, "--font", FONT, "--out", self.out,
                "--kfgqpc", self.write_kfgqpc(), "--table", self.write_table(),
            )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("refused: the KFGQPC comparison passes", err)
        self.assertIn("manifest format 1 has no place", err)
        self.assertFalse((self.out / HAFS_ID).exists())

    def test_kfgqpc_counts(self):
        out_file = self.work / "counts.json"
        with hafs_shaped_profiles():
            code, out, _ = self.run_cli(
                "kfgqpc-counts", "--kfgqpc", self.write_kfgqpc(), "--date", "2026-11-06", "--out", out_file
            )
        self.assertEqual(code, 0, out)
        self.assertIn("surahs 3 ayat 8", out)
        counts = json.loads(out_file.read_bytes())
        self.assertEqual((counts["surahs"], counts["total"]), ({"1": 4, "2": 3, "3": 1}, 8))

    def test_kfgqpc_counts_on_the_real_profile_refuses_a_short_file(self):
        out_file = self.work / "counts.json"
        code, _, err = self.run_cli(
            "kfgqpc-counts", "--kfgqpc", self.write_kfgqpc(), "--date", "2026-11-06", "--out", out_file
        )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("not 6236", err)
        self.assertFalse(out_file.exists())


class TafsirCliCase(CliCase):
    def tafsir(self, fault=None):
        return tafsir_pack_factory.write_pack(self.work / "packs" / (fault or "clean"), fault=fault)

    def ayah_counts(self):
        path = self.work / "kfgqpc-hafs-counts.json"
        path.write_bytes(encode_counts(kfgqpc_counts(self.write_kfgqpc(), "2026-11-06", PROFILES["synthetic"])))
        return path


class TafsirVerifyTest(TafsirCliCase):
    def test_verify_chooses_the_tafsir_checks(self):
        code, out, _ = self.run_cli("verify", self.tafsir(), "--ayah-counts", self.ayah_counts())
        self.assertEqual(code, 0, out)
        self.assertIn("counts passages 5", out)
        self.assertIn("verified", out)
        self.assertIn("unsigned", out)

    def test_verify_with_the_tafsir_font_reports_what_it_lacks(self):
        code, out, _ = self.run_cli("verify", self.tafsir(), "--ayah-counts", self.ayah_counts(), "--font", FONT)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertRegex(out, r"problem: U\+[0-9A-F]{4,} is not in the font; first at ")

    def test_verify_reports_a_tafsir_fault(self):
        code, out, _ = self.run_cli("verify", self.tafsir("overlap"), "--ayah-counts", self.ayah_counts())
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("problem: passages 2 and 3 overlap", out)
        self.assertIn("1 problems", out)

    def test_the_counts_decide_the_ranges(self):
        counts = self.ayah_counts()
        data = counts.read_bytes().replace(b'"1": 4', b'"1": 3').replace(b'"total": 8', b'"total": 7')
        counts.write_bytes(data)
        code, out, _ = self.run_cli("verify", self.tafsir(), "--ayah-counts", counts)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("problem: passage 3 reaches ayah 4 of surah 1, which has 3", out)

    def test_a_counts_file_that_is_not_p5_is_refused(self):
        counts = self.ayah_counts()
        counts.write_bytes(counts.read_bytes().rstrip(b"\n"))
        code, _, err = self.run_cli("verify", self.tafsir(), "--ayah-counts", counts)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("refused: ayah counts:", err)

    def test_inputs_of_the_other_kind_are_usage_errors(self):
        tafsir = self.tafsir()
        counts = self.ayah_counts()
        self.assertEqual(self.run_cli("verify", tafsir)[0], cli.EX_USAGE)
        self.assertEqual(
            self.run_cli("verify", tafsir, "--ayah-counts", counts, "--mark-table", counts)[0], cli.EX_USAGE
        )
        text, _ = self.build()
        code, _, err = self.run_cli("verify", text, "--ayah-counts", counts)
        self.assertEqual(code, cli.EX_USAGE)
        self.assertIn("--ayah-counts is for a tafsir pack", err)

    def test_sign_of_a_tafsir_pack_needs_its_font(self):
        tafsir = self.tafsir()
        code, _, err = self.run_cli("sign", tafsir, "--key", self.work / "absent.pem", "--ayah-counts", self.ayah_counts())
        self.assertEqual(code, cli.EX_USAGE)
        self.assertIn("sign needs --font for a tafsir pack", err)
        self.assertFalse((tafsir / "manifest.json.sig").exists())

    def test_a_tafsir_pack_that_does_not_verify_is_not_signed(self):
        tafsir = self.tafsir("gap_in_numbering")
        code, out, err = self.run_cli(
            "sign", tafsir, "--key", self.work / "absent.pem", "--ayah-counts", self.ayah_counts(), "--font", OTHER_FONT
        )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("problem: passage 3 is numbered 4", out)
        self.assertIn("not signed", err)
        self.assertFalse((tafsir / "manifest.json.sig").exists())


@unittest.skipUnless(_openssl_ed25519(), "needs OpenSSL with Ed25519")
class SignTest(TafsirCliCase):
    def keys(self, name):
        private, public = self.work / (name + ".pem"), self.work / (name + ".pub.pem")
        for argv in (
            ["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(private)],
            ["openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)],
        ):
            subprocess.run(argv, check=True, capture_output=True)
        return private, public

    def test_sign_then_verify_signature(self):
        pack, _ = self.build()
        private, public = self.keys("throwaway")
        code, out, _ = self.run_cli(
            "sign", pack, "--key", private, "--font", FONT, "--mark-table", self.source / "marks.json"
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(len((pack / "manifest.json.sig").read_bytes()), 64)
        self.assertEqual(self.run_cli("verify-signature", pack, "--public-key", public)[0], 0)
        code, out, _ = self.run_cli("verify", pack)
        self.assertEqual(code, 0)
        self.assertIn("present, not checked here", out)
        _, other = self.keys("other")
        code, out, _ = self.run_cli("verify-signature", pack, "--public-key", other)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("INVALID", out)

    def test_a_test_copy_is_signed_with_a_pem_key_and_checked_with_its_public_key(self):
        with hafs_shaped_profiles():
            code, _, _ = self.run_cli(
                "build", "--config", self.write_source(riwaya="hafs", id=TEST_COPY_ID, reviews=[]),
                "--font", FONT, "--out", self.out, "--unapproved-test-copy",
            )
        self.assertEqual(code, 0)
        pack = self.out / TEST_COPY_ID / "1"
        private, public = self.keys("test-copy")
        code, out, _ = self.run_cli(
            "sign", pack, "--key", private, "--font", FONT, "--mark-table", self.source / "marks.json"
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(self.run_cli("verify-signature", pack, "--public-key", public)[0], 0)

    def test_sign_a_tafsir_pack_then_verify_signature(self):
        tafsir = self.tafsir()
        private, public = self.keys("throwaway")
        code, out, _ = self.run_cli(
            "sign", tafsir, "--key", private, "--ayah-counts", self.ayah_counts(), "--font", OTHER_FONT
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(len((tafsir / "manifest.json.sig").read_bytes()), 64)
        self.assertEqual(self.run_cli("verify-signature", tafsir, "--public-key", public)[0], 0)

    def test_sign_needs_the_font_and_the_mark_table(self):
        pack, _ = self.build()
        private, _ = self.keys("throwaway")
        self.assertEqual(self.run_cli("sign", pack, "--key", private, "--font", FONT)[0], cli.EX_USAGE)
        self.assertFalse((pack / "manifest.json.sig").exists())

    def test_a_pack_that_does_not_verify_is_not_signed(self):
        pack, _ = self.build()
        (pack / "stray.txt").write_bytes(b"x")
        private, _ = self.keys("throwaway")
        code, _, err = self.run_cli(
            "sign", pack, "--key", private, "--font", FONT, "--mark-table", self.source / "marks.json"
        )
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("not signed", err)
        self.assertFalse((pack / "manifest.json.sig").exists())


if __name__ == "__main__":
    unittest.main()
