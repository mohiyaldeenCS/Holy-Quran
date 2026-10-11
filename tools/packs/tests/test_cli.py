"""The command line, in process and once as a script."""

import io
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from hqpack import cli

from tests.build_support import FONT, BuildCase

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


@unittest.skipUnless(_openssl_ed25519(), "needs OpenSSL with Ed25519")
class SignTest(CliCase):
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
        code, out, _ = self.run_cli("sign", pack, "--key", private, "--font", FONT)
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

    def test_a_pack_that_does_not_verify_is_not_signed(self):
        pack, _ = self.build()
        (pack / "stray.txt").write_bytes(b"x")
        private, _ = self.keys("throwaway")
        code, _, err = self.run_cli("sign", pack, "--key", private)
        self.assertEqual(code, cli.EX_DATAERR)
        self.assertIn("not signed", err)
        self.assertFalse((pack / "manifest.json.sig").exists())


if __name__ == "__main__":
    unittest.main()
