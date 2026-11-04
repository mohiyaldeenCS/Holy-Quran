"""tools/test_copy/: the provisional mark table, the build description template and the script's guards (D-165)."""

import copy
import json
import os
import re
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

    def test_the_readme_table_lists_these_code_points_with_their_unicode_names(self):
        readme = (TEST_COPY / "README.md").read_text(encoding="utf-8")
        rows = re.findall(r"^\| `U\+([0-9A-F]{4})` \| (.+) \|$", readme, re.MULTILINE)
        self.assertEqual({int(code, 16) for code, _ in rows}, set(read_mark_table(self.data)))
        for code, name in rows:
            self.assertEqual(name, unicodedata.name(chr(int(code, 16))))


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
        data["sources"]["edition_map"]["url"] = "https://example.invalid/metadata.xml"
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
                ("edition_map", "url"),
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


class ScriptRepoCase(unittest.TestCase):
    """The script copied into a throwaway Git repository."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack script "))
        self.addCleanup(shutil.rmtree, str(self.work), True)
        self.repo = self.work / "repo"
        folder = self.repo / "tools" / "test_copy"
        folder.mkdir(parents=True)
        shutil.copy(str(SCRIPT), str(folder / "test_copy.sh"))
        shutil.copy(str(TEST_COPY / "provisional_marks.json"), str(folder / "provisional_marks.json"))
        (self.repo / ".gitignore").write_text("build/\n", encoding="utf-8")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "x")
        self.outside = self.work / "outside"

    def git(self, *argv):
        subprocess.run(["git", "-C", str(self.repo), *argv], check=True, capture_output=True)

    def run_script(self, *argv, work=None, path=None, extra=None):
        env = {"PATH": path or os.environ["PATH"], "HOME": str(self.work), "HQ_TEST_COPY_DIR": str(work or self.outside)}
        env.update(extra or {})
        return subprocess.run(
            [BASH, str(self.repo / "tools" / "test_copy" / "test_copy.sh"), *argv],
            capture_output=True,
            text=True,
            env=env,
        )


@unittest.skipUnless(BASH and GIT, "needs bash and git")
class ScriptGuardTest(ScriptRepoCase):
    """The script run until its first refusal."""

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

    def test_a_work_folder_under_the_git_folder_is_refused(self):
        for command in ("pack", "install"):
            with self.subTest(command=command):
                done = self.run_script(command, work=self.repo / ".git" / "x")
                self.assertNotEqual(done.returncode, 0)
                self.assertIn("inside the repository", done.stderr)
        self.assertFalse((self.repo / ".git" / "x").exists())

    def test_a_work_folder_inside_the_repository_is_not_created(self):
        inside = self.repo / "deep" / "holyquran-test-copy"
        done = self.run_script("pack", work=inside)
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("inside a Git working tree", done.stderr)
        self.assertFalse((self.repo / "deep").exists())

    def test_a_work_folder_reached_through_a_link_into_the_repository_is_not_created(self):
        link = self.work / "link"
        try:
            link.symlink_to(self.repo, target_is_directory=True)
        except OSError:
            self.skipTest("symbolic links are not available")
        done = self.run_script("pack", work=link / "deep" / "x")
        self.assertNotEqual(done.returncode, 0)
        self.assertFalse((self.repo / "deep").exists())

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


STUB_PYTHON = """#!/usr/bin/env bash
echo "python $2" >>"$STUB_LOG"
case "$2" in
  build) mkdir -p "$STUB_PACK" ;;
  sign)
    [ -f "$STUB_KEYS/test-copy.pem" ] || exit 9
    [ "${STUB_FAIL:-}" != sign ] || exit 7
    echo sig >"$STUB_PACK/manifest.json.sig"
    ;;
esac
"""

STUB_FLUTTER = """#!/usr/bin/env bash
echo "flutter $1" >>"$STUB_LOG"
case "$1" in
  test)
    [ "${STUB_DIRTY:-}" != test ] || echo stray >stray-from-test.txt
    [ -z "${STUB_MODIFY:-}" ] || echo changed >"$STUB_MODIFY"
    ;;
  build)
    mkdir -p build/app/outputs/flutter-apk build/app/outputs/apk/profile
    for apk in build/app/outputs/flutter-apk/app-profile.apk build/app/outputs/apk/profile/app-profile.apk; do
      echo apk >"$apk"
      echo sum >"$apk.sha1"
    done
    [ "${STUB_DIRTY:-}" != build ] || echo stray >stray-from-build.txt
    ;;
esac
"""

STUB_ADB = """#!/usr/bin/env bash
echo "adb $1" >>"$STUB_LOG"
[ "${STUB_FAIL:-}" != "adb $1" ] || exit 7
[ "${STUB_DIRTY:-}" != adb ] || echo stray >stray-from-adb.txt
exit 0
"""


@unittest.skipUnless(BASH and GIT and shutil.which("openssl"), "needs bash, git and openssl")
class ScriptRunTest(ScriptRepoCase):
    """The whole script, with a stub Python, flutter and adb in place of the real programs."""

    PACK_ID = "unapproved-hafs-tanzil"

    def setUp(self):
        super().setUp()
        self.stubs = Path(tempfile.mkdtemp(prefix="hqstub"))
        self.addCleanup(shutil.rmtree, str(self.stubs), True)
        for name, body in (("python", STUB_PYTHON), ("flutter", STUB_FLUTTER), ("adb", STUB_ADB)):
            stub = self.stubs / name
            stub.write_text(body, encoding="utf-8")
            stub.chmod(0o755)
        self.log = self.stubs / "log.txt"
        self.keys = self.outside / "keys"
        self.pack = self.outside / "packs" / self.PACK_ID / "1"
        (self.outside / "raw").mkdir(parents=True)
        for name in ("quran-uthmani.xml", "quran-data.xml"):
            (self.outside / "raw" / name).write_text("<synthetic/>", encoding="utf-8")
        (self.outside / "build.json").write_text("{}", encoding="utf-8")

    def run_stubbed(self, command, **extra):
        env = {
            "PYTHON": str(self.stubs / "python"),
            "STUB_LOG": str(self.log),
            "STUB_PACK": str(self.pack),
            "STUB_KEYS": str(self.keys),
        }
        env.update(extra)
        return self.run_script(command, path=str(self.stubs) + os.pathsep + os.environ["PATH"], extra=env)

    def calls(self):
        return self.log.read_text(encoding="utf-8").split("\n")[:-1] if self.log.exists() else []

    def make_signed_pack(self):
        self.pack.mkdir(parents=True)
        (self.pack / "manifest.json.sig").write_text("sig", encoding="utf-8")
        self.keys.mkdir(parents=True)
        (self.keys / "test-copy.pub.b64").write_text("key", encoding="utf-8")

    def assert_no_private_key(self):
        self.assertFalse((self.keys / "test-copy.pem").exists())

    def test_pack_succeeds_and_leaves_no_private_key(self):
        done = self.run_stubbed("pack")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn("unbound", done.stderr)
        self.assertEqual(
            self.calls(),
            ["python build", "python verify", "flutter test", "python sign", "python verify-signature"],
        )
        self.assert_no_private_key()
        self.assertTrue((self.keys / "test-copy.pub.b64").is_file())
        self.assertTrue((self.pack / "manifest.json.sig").is_file())

    def test_pack_that_fails_at_signing_leaves_no_private_key(self):
        done = self.run_stubbed("pack", STUB_FAIL="sign")
        self.assertNotEqual(done.returncode, 0)
        self.assertNotIn("unbound", done.stderr)
        self.assertEqual(self.calls()[-1], "python sign")
        self.assert_no_private_key()

    def test_a_dirty_tree_message_names_one_exact_command_per_file(self):
        self.make_signed_pack()
        done = self.run_stubbed("install", STUB_DIRTY="build")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("  git clean -f -- stray-from-build.txt\n", done.stderr)
        self.assertNotIn("git checkout -- .", done.stderr)
        self.assertNotIn("git clean -fd", done.stderr)

    def test_the_after_message_lists_modified_and_untracked_files_separately(self):
        done = self.run_stubbed("pack", STUB_DIRTY="test", STUB_MODIFY="tools/test_copy/provisional_marks.json")
        self.assertIn("  git checkout -- tools/test_copy/provisional_marks.json\n", done.stderr)
        self.assertIn("  git clean -f -- stray-from-test.txt\n", done.stderr)
        self.assertNotIn("git checkout -- .", done.stderr)

    def test_pack_and_install_refuse_a_leftover_private_key(self):
        self.make_signed_pack()
        (self.keys / "test-copy.pem").write_text("left", encoding="utf-8")
        for command in ("pack", "install"):
            with self.subTest(command=command):
                done = self.run_stubbed(command)
                self.assertNotEqual(done.returncode, 0)
                self.assertIn("test-copy.pem exists", done.stderr)
                self.assertEqual(self.calls(), [])
        self.assertTrue((self.keys / "test-copy.pem").exists())

    def test_pack_refuses_a_tree_the_tests_changed(self):
        done = self.run_stubbed("pack", STUB_DIRTY="test")
        self.assertNotEqual(done.returncode, 0)
        self.assertNotIn("python sign", self.calls())
        self.assertFalse((self.pack / "manifest.json.sig").exists())
        self.assertIn("stray-from-test.txt", done.stderr)
        self.assertIn("the build changed the Git working tree", done.stderr)
        self.assert_no_private_key()

    def test_install_succeeds_and_deletes_every_apk(self):
        self.make_signed_pack()
        done = self.run_stubbed("install")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(
            self.calls(), ["flutter build", "adb install", "adb shell", "adb push"]
        )
        self.assertEqual(list((self.repo / "build").rglob("*.apk*")), [])

    def test_install_refuses_a_tree_the_build_changed_and_deletes_every_apk(self):
        self.make_signed_pack()
        done = self.run_stubbed("install", STUB_DIRTY="build")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("stray-from-build.txt", done.stderr)
        self.assertNotIn("adb install", self.calls())
        self.assertEqual(list((self.repo / "build").rglob("*.apk*")), [])

    def test_install_refuses_a_tree_changed_after_the_push(self):
        self.make_signed_pack()
        done = self.run_stubbed("install", STUB_DIRTY="adb")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("stray-from-adb.txt", done.stderr)
        self.assertEqual(list((self.repo / "build").rglob("*.apk*")), [])

    def test_install_that_fails_at_adb_deletes_every_apk(self):
        self.make_signed_pack()
        done = self.run_stubbed("install", STUB_FAIL="adb install")
        self.assertNotEqual(done.returncode, 0)
        self.assertEqual(list((self.repo / "build").rglob("*.apk*")), [])


if __name__ == "__main__":
    unittest.main()
