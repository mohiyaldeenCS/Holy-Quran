"""tools/test_copy/: the provisional mark table, the build description template and the script's guards (D-165)."""

import copy
import json
import os
import shutil
import subprocess
import tempfile
import unicodedata
import unittest
from pathlib import Path

from hqpack.config import read_build_config
from hqpack.errors import PackError
from hqpack.mark_table import read_mark_table

from tests.build_support import REPO, TEST_COPY_ID

TEST_COPY = REPO / "tools" / "test_copy"
SCRIPT = TEST_COPY / "test_copy.sh"
BASH = shutil.which("bash")
GIT = shutil.which("git")

# D-079 leaves U+06DE out; U+06E5 and U+06E6 are letters (category Lm), which
# a mark table may not hold (mark_table.py, D-083).
RANGE = set(range(0x06D6, 0x06EE))
LEFT_OUT = {0x06DE, 0x06E5, 0x06E6}


class ProvisionalMarksTest(unittest.TestCase):
    def setUp(self):
        self.data = (TEST_COPY / "provisional_marks.json").read_bytes()

    def test_it_holds_the_unicode_quranic_annotation_signs_and_nothing_else(self):
        self.assertEqual(read_mark_table(self.data), frozenset(RANGE - LEFT_OUT))

    def test_what_is_left_out_is_the_rub_el_hizb_sign_and_the_letters(self):
        table = read_mark_table(self.data)
        self.assertNotIn(0x06DE, table)
        self.assertEqual(
            {cp for cp in RANGE - table if cp != 0x06DE},
            {cp for cp in RANGE if unicodedata.category(chr(cp)).startswith("L")},
        )

    def test_it_is_plain_ascii(self):
        self.assertTrue(self.data.isascii())


class TemplateTest(unittest.TestCase):
    def setUp(self):
        self.template = json.loads((TEST_COPY / "build.template.json").read_text(encoding="utf-8"))

    def filled(self, directory):
        data = copy.deepcopy(self.template)
        for role in ("text", "edition_map"):
            source = data["sources"][role]
            source["file_sha256"] = "0" * 64
            source["fetched_on"] = "2026-11-04"
        data["sources"]["edition_map"]["version"] = "1"
        path = Path(directory) / "build.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_the_placeholders_are_the_only_unfilled_fields(self):
        placeholders = sorted(
            (role, key)
            for role, source in self.template["sources"].items()
            for key, value in source.items()
            if isinstance(value, str) and "FILL_IN" in value
        )
        self.assertEqual(
            placeholders,
            [
                ("edition_map", "fetched_on"),
                ("edition_map", "file_sha256"),
                ("edition_map", "version"),
                ("text", "fetched_on"),
                ("text", "file_sha256"),
            ],
        )

    def test_filled_in_it_is_a_valid_build_description(self):
        with tempfile.TemporaryDirectory() as work:
            config = read_build_config(self.filled(work))
        self.assertEqual((config.pack_id, config.version, config.riwaya), (TEST_COPY_ID, 1, "hafs"))
        self.assertEqual(config.reviews, [])
        self.assertEqual((config.text.registry_row, config.edition_map.registry_row), (1, 4))
        self.assertEqual(config.text.version, "1.1")

    def test_as_it_is_it_is_refused(self):
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / "build.json"
            path.write_bytes((TEST_COPY / "build.template.json").read_bytes())
            with self.assertRaises(PackError):
                read_build_config(path)

    def test_the_source_options_are_those_of_d079(self):
        url = self.template["sources"]["text"]["url"]
        for option in ("marks=true", "sajdah=true", "rub=false", "outType=xml", "quranType=uthmani"):
            self.assertIn(option, url)
        self.assertEqual(self.template["reviews"], [])

    def test_the_licences_keep_the_credit_conditions_of_the_register(self):
        for source in self.template["sources"].values():
            self.assertIn("verbatim only", source["licence"]["text"])
            self.assertIn("RIGHTS_REGISTER.md", source["licence"]["permission_ref"])


@unittest.skipUnless(BASH, "needs bash")
class ScriptSyntaxTest(unittest.TestCase):
    def test_bash_accepts_the_script(self):
        done = subprocess.run([BASH, "-n", str(SCRIPT)], capture_output=True)
        self.assertEqual(done.returncode, 0, done.stderr)

    def test_the_script_never_builds_release(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("flutter build apk --profile", text)
        self.assertNotIn("--release", text)
        self.assertIn("set -euo pipefail", text)

    @unittest.skipUnless(shutil.which("shellcheck"), "needs shellcheck")
    def test_shellcheck_is_clean(self):
        done = subprocess.run(["shellcheck", str(SCRIPT)], capture_output=True)
        self.assertEqual(done.returncode, 0, done.stdout)


@unittest.skipUnless(BASH and GIT, "needs bash and git")
class ScriptGuardTest(unittest.TestCase):
    """The script copied into a throwaway repository, run until its first refusal."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack script "))
        self.addCleanup(shutil.rmtree, str(self.work), True)
        self.repo = self.work / "repo"
        folder = self.repo / "tools" / "test_copy"
        folder.mkdir(parents=True)
        shutil.copy(str(SCRIPT), str(folder / "test_copy.sh"))
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "x")
        self.outside = self.work / "outside"

    def git(self, *argv):
        subprocess.run(["git", "-C", str(self.repo), *argv], check=True, capture_output=True)

    def run_script(self, *argv, work=None):
        env = {"PATH": os.environ["PATH"], "HOME": str(self.work), "HQ_TEST_COPY_DIR": str(work or self.outside)}
        return subprocess.run(
            [BASH, str(self.repo / "tools" / "test_copy" / "test_copy.sh"), *argv],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_a_dirty_tree_is_refused(self):
        (self.repo / "stray.txt").write_text("x", encoding="utf-8")
        for command in ("pack", "install"):
            with self.subTest(command=command):
                done = self.run_script(command)
                self.assertNotEqual(done.returncode, 0)
                self.assertIn("not clean", done.stderr)
                self.assertIn("stray.txt", done.stderr)

    def test_a_work_folder_inside_the_repository_is_refused(self):
        for command in ("pack", "install"):
            with self.subTest(command=command):
                done = self.run_script(command, work=self.repo / "holyquran-test-copy")
                self.assertNotEqual(done.returncode, 0)
                self.assertIn("inside a Git working tree", done.stderr)

    def test_a_work_folder_inside_another_repository_is_refused(self):
        other = self.work / "other"
        other.mkdir()
        subprocess.run(["git", "-C", str(other), "init", "-q"], check=True, capture_output=True)
        done = self.run_script("pack", work=other / "sub")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("inside a Git working tree", done.stderr)

    def test_a_missing_build_description_stops_the_pack_step(self):
        done = self.run_script("pack")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("build.json is missing", done.stderr)

    def test_a_placeholder_left_in_the_description_stops_the_pack_step(self):
        self.outside.mkdir()
        shutil.copy(str(TEST_COPY / "build.template.json"), str(self.outside / "build.json"))
        done = self.run_script("pack")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("FILL_IN", done.stderr)

    def test_install_needs_a_signed_pack(self):
        done = self.run_script("install")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("not a signed pack", done.stderr)

    def test_unknown_commands_and_arguments_are_refused(self):
        for argv in ((), ("release",), ("install", "--release"), ("pack", "x")):
            with self.subTest(argv=argv):
                done = self.run_script(*argv)
                self.assertNotEqual(done.returncode, 0)
                self.assertIn("usage", done.stderr)


if __name__ == "__main__":
    unittest.main()
