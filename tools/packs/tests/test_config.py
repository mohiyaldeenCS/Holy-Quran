from __future__ import annotations

import copy
import os
import json
import tempfile
import unittest
from pathlib import Path

import synthetic_source
from hqpack.config import read_build_config
from hqpack.errors import PackError

TEXT_SHA = "a" * 64
METADATA_SHA = "b" * 64


def _default():
    return synthetic_source.synthetic_build_config(TEXT_SHA, METADATA_SHA)


def _set(document, path, value):
    *parents, last = path
    for key in parents:
        document = document[key]
    document[last] = value


def _delete(document, path):
    *parents, last = path
    for key in parents:
        document = document[key]
    del document[last]


class ConfigTestCase(unittest.TestCase):
    def setUp(self):
        self._work = tempfile.TemporaryDirectory()
        self.directory = Path(self._work.name)
        self.path = self.directory / "build.json"

    def tearDown(self):
        self._work.cleanup()

    def write_bytes(self, data: bytes) -> Path:
        self.path.write_bytes(data)
        return self.path

    def write(self, document) -> Path:
        return self.write_bytes(
            (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        )

    def assertRefusedBytes(self, data: bytes, *fragments):
        self.write_bytes(data)
        return self._refused(fragments)

    def assertRefused(self, document, *fragments):
        self.write(document)
        return self._refused(fragments)

    def _refused(self, fragments):
        with self.assertRaises(PackError) as caught:
            read_build_config(self.path)
        message = str(caught.exception)
        message.encode("ascii")
        for fragment in fragments:
            self.assertIn(fragment, message)
        return message

    def assertFieldRefused(self, path, value, label):
        document = _default()
        _set(document, path, value)
        with self.subTest(field=label, value=value):
            self.assertRefused(document, label)


class AcceptsTest(ConfigTestCase):
    def test_reads_the_synthetic_description(self):
        config = read_build_config(self.write(_default()))
        self.assertEqual(config.path, Path(os.path.abspath(self.path)))
        self.assertEqual(config.pack_id, "synthetic-text")
        self.assertEqual(config.version, 1)
        self.assertEqual(config.riwaya, "synthetic")
        self.assertEqual(config.edition, "synthetic-edition")
        self.assertEqual(config.changelog, _default()["changelog"])
        self.assertEqual(config.reviews, _default()["reviews"])
        self.assertEqual(config.mark_table, self.path.resolve().parent / "marks.json")

    def test_reads_both_sources(self):
        config = read_build_config(self.write(_default()))
        base = self.path.resolve().parent
        self.assertEqual(config.text.role, "text")
        self.assertEqual(config.text.file, base / "text.xml")
        self.assertEqual(config.text.file_sha256, TEXT_SHA)
        self.assertEqual(config.text.registry_row, 1)
        self.assertEqual(config.text.trust_grade, "A")
        self.assertEqual(config.text.fetched_on, "2026-01-01")
        self.assertEqual(
            config.text.licence,
            {"text": None, "permission_ref": "Synthetic permission 1", "allows_export": True},
        )
        self.assertEqual(config.edition_map.role, "edition_map")
        self.assertEqual(config.edition_map.file, base / "metadata.xml")
        self.assertEqual(config.edition_map.file_sha256, METADATA_SHA)
        self.assertEqual(config.edition_map.registry_row, 4)
        self.assertEqual(config.edition_map.url, "https://example.invalid/synthetic/metadata")

    def test_resolves_a_nested_relative_path(self):
        document = _default()
        document["sources"]["text"]["file"] = "raw/text.xml"
        config = read_build_config(self.write(document))
        self.assertEqual(config.text.file, self.path.resolve().parent / "raw" / "text.xml")

    def test_accepts_no_reviews(self):
        document = _default()
        document["reviews"] = []
        self.assertEqual(read_build_config(self.write(document)).reviews, [])

    def test_accepts_a_licence_text_without_a_permission(self):
        document = _default()
        document["sources"]["text"]["licence"] = {
            "text": "Synthetic licence", "permission_ref": None, "allows_export": False,
        }
        config = read_build_config(self.write(document))
        self.assertEqual(config.text.licence["text"], "Synthetic licence")
        self.assertFalse(config.text.licence["allows_export"])

    def test_accepts_an_older_changelog_entry_beside_the_current_one(self):
        document = _default()
        document["version"] = 2
        document["changelog"].append(
            {"version": 2, "date": "2026-02-01", "summary": "Synthetic second"}
        )
        self.assertEqual(read_build_config(self.write(document)).version, 2)


class FileFormTest(ConfigTestCase):
    def test_refuses_a_missing_file(self):
        with self.assertRaises(PackError):
            read_build_config(self.directory / "absent.json")

    def test_refuses_a_byte_order_mark(self):
        data = b"\xef\xbb\xbf" + json.dumps(_default()).encode("utf-8")
        self.assertRefusedBytes(data, "byte order mark")

    def test_refuses_malformed_utf8(self):
        self.assertRefusedBytes(b'{"id": "\xff"}', "UTF-8")

    def test_refuses_text_that_is_not_json(self):
        self.assertRefusedBytes(b"{", "JSON")

    def test_refuses_a_repeated_key(self):
        self.assertRefusedBytes(b'{"id": "a", "id": "b"}', "repeated key id")

    def test_refuses_a_repeated_nested_key(self):
        text = json.dumps(_default()).replace(
            '"registry_row": 1,', '"registry_row": 1, "registry_row": 1,'
        )
        self.assertRefusedBytes(text.encode("utf-8"), "repeated key registry_row")

    def test_refuses_nan(self):
        text = json.dumps(_default()).replace('"version": 1,', '"version": NaN,', 1)
        self.assertRefusedBytes(text.encode("utf-8"), "NaN")

    def test_refuses_a_document_that_is_not_an_object(self):
        self.assertRefused([], "must be an object")


class KeysTest(ConfigTestCase):
    def test_refuses_each_missing_top_level_key(self):
        for key in _default():
            document = _default()
            del document[key]
            with self.subTest(key=key):
                self.assertRefused(document, key, "missing")

    def test_refuses_an_unknown_top_level_key(self):
        document = _default()
        document["extra"] = 1
        self.assertRefused(document, "unknown key extra")

    def test_refuses_each_missing_source_key(self):
        for role in ("text", "edition_map"):
            for key in _default()["sources"][role]:
                document = _default()
                _delete(document, ("sources", role, key))
                with self.subTest(role=role, key=key):
                    self.assertRefused(document, "sources.%s.%s" % (role, key), "missing")

    def test_refuses_an_unknown_source_key(self):
        document = _default()
        document["sources"]["edition_map"]["options"] = None
        self.assertRefused(document, "sources.edition_map.options")

    def test_refuses_a_missing_or_unknown_role(self):
        document = _default()
        del document["sources"]["edition_map"]
        self.assertRefused(document, "sources.edition_map", "missing")
        document = _default()
        document["sources"]["search"] = copy.deepcopy(document["sources"]["text"])
        self.assertRefused(document, "sources.search")

    def test_refuses_sources_that_are_not_an_object(self):
        document = _default()
        document["sources"] = []
        self.assertRefused(document, "sources must be an object")

    def test_an_unknown_non_ascii_key_is_not_echoed(self):
        document = _default()
        document["\u0646\u0635"] = 1
        message = self.assertRefused(document, "unknown key")
        self.assertNotIn("\u0646", message)


class TopLevelValuesTest(ConfigTestCase):
    def test_refuses_a_bad_id(self):
        for value in ("Synthetic", "a--b", "-a", "a-", "a_b", "", 5, None):
            self.assertFieldRefused(("id",), value, "id")

    def test_refuses_a_version_that_is_not_a_positive_integer(self):
        for value in (0, -1, True, "1", 1.0, None):
            self.assertFieldRefused(("version",), value, "version")

    def test_refuses_a_bad_riwaya(self):
        for value in ("Hafs", "1hafs", "_hafs", "ha-fs", "", None):
            self.assertFieldRefused(("riwaya",), value, "riwaya")

    def test_refuses_a_bad_edition(self):
        for value in ("", "\ufeffsynthetic", 3, None):
            self.assertFieldRefused(("edition",), value, "edition")

    def test_refuses_a_string_beginning_with_a_byte_order_mark(self):
        message = self.assertRefused(
            _with(("sources", "text", "name"), "\ufeffSynthetic"),
            "sources.text.name", "U+FEFF",
        )
        self.assertNotIn("Synthetic", message)


class ChangelogTest(ConfigTestCase):
    def test_refuses_an_empty_or_non_list_changelog(self):
        for value in ([], {}, None):
            self.assertFieldRefused(("changelog",), value, "changelog")

    def test_refuses_a_bad_entry(self):
        cases = (
            (("changelog", 0), "entry", "changelog[0]"),
            (("changelog", 0, "version"), 0, "changelog[0].version"),
            (("changelog", 0, "version"), True, "changelog[0].version"),
            (("changelog", 0, "date"), "2026-02-30", "changelog[0].date"),
            (("changelog", 0, "date"), "2026-1-01", "changelog[0].date"),
            (("changelog", 0, "date"), "2026-01-01T00:00", "changelog[0].date"),
            (("changelog", 0, "summary"), "", "changelog[0].summary"),
            (("changelog", 0, "extra"), 1, "changelog[0].extra"),
        )
        for path, value, label in cases:
            self.assertFieldRefused(path, value, label)

    def test_refuses_a_missing_entry_key(self):
        for key in ("version", "date", "summary"):
            document = _default()
            del document["changelog"][0][key]
            with self.subTest(key=key):
                self.assertRefused(document, "changelog[0].%s" % key, "missing")

    def test_refuses_a_changelog_without_the_current_version(self):
        self.assertRefused(_with(("version",), 2), "changelog", "version 2")


class SourceValuesTest(ConfigTestCase):
    def test_refuses_bad_values(self):
        cases = (
            ("file_sha256", "A" * 64),
            ("file_sha256", "a" * 63),
            ("file_sha256", "g" * 64),
            ("registry_row", 0),
            ("registry_row", True),
            ("registry_row", "1"),
            ("trust_grade", "D"),
            ("trust_grade", "a"),
            ("trust_grade", None),
            ("fetched_on", "2026-13-01"),
            ("fetched_on", "01-01-2026"),
            ("url", "http://example.invalid/x"),
            ("url", "https://"),
            ("url", "ftp://example.invalid"),
            ("name", ""),
            ("publisher", None),
            ("version", 1),
            ("version", ""),
            ("licence", None),
        )
        for role in ("text", "edition_map"):
            for key, value in cases:
                self.assertFieldRefused(
                    ("sources", role, key), value, "sources.%s.%s" % (role, key)
                )


class LicenceTest(ConfigTestCase):
    def test_refuses_a_notice_and_says_where_it_comes_from(self):
        document = _default()
        document["sources"]["text"]["licence"]["notice"] = "Synthetic notice"
        message = self.assertRefused(document, "sources.text.licence.notice")
        self.assertIn("source file", message)
        self.assertNotIn("Synthetic notice", message)

    def test_refuses_a_licence_with_neither_text_nor_permission(self):
        document = _default()
        document["sources"]["edition_map"]["licence"]["permission_ref"] = None
        self.assertRefused(document, "sources.edition_map.licence")

    def test_refuses_bad_licence_values(self):
        cases = (
            ("text", ""),
            ("text", 5),
            ("permission_ref", ""),
            ("permission_ref", ["x"]),
            ("allows_export", "true"),
            ("allows_export", 1),
            ("allows_export", None),
            ("extra", True),
        )
        for key, value in cases:
            self.assertFieldRefused(
                ("sources", "text", "licence", key), value, "sources.text.licence.%s" % key
            )

    def test_refuses_a_missing_licence_key(self):
        for key in ("text", "permission_ref", "allows_export"):
            document = _default()
            del document["sources"]["text"]["licence"][key]
            with self.subTest(key=key):
                self.assertRefused(document, "sources.text.licence.%s" % key, "missing")


class PathsTest(ConfigTestCase):
    def test_refuses_absolute_paths_and_parent_components(self):
        values = (
            "/tmp/text.xml",
            "\\text.xml",
            "C:\\text.xml",
            "C:text.xml",
            "../text.xml",
            "raw/../text.xml",
            "raw\\..\\text.xml",
            "..",
            "",
            None,
        )
        for value in values:
            self.assertFieldRefused(("sources", "text", "file"), value, "sources.text.file")
            self.assertFieldRefused(("mark_table",), value, "mark_table")


class ReviewsTest(ConfigTestCase):
    def test_refuses_reviews_that_are_not_a_list(self):
        for value in ({}, None, "x"):
            self.assertFieldRefused(("reviews",), value, "reviews")

    def test_refuses_a_bad_review(self):
        cases = (
            (("reviews", 0), [], "reviews[0]"),
            (("reviews", 0, "reviewer"), "", "reviews[0].reviewer"),
            (("reviews", 0, "date"), "2026-02-29", "reviews[0].date"),
            (("reviews", 0, "scope"), None, "reviews[0].scope"),
            (("reviews", 0, "extra"), "x", "reviews[0].extra"),
        )
        for path, value, label in cases:
            self.assertFieldRefused(path, value, label)

    def test_refuses_a_missing_review_key(self):
        for key in ("reviewer", "date", "scope"):
            document = _default()
            del document["reviews"][0][key]
            with self.subTest(key=key):
                self.assertRefused(document, "reviews[0].%s" % key, "missing")


def _with(path, value):
    document = _default()
    _set(document, path, value)
    return document


if __name__ == "__main__":
    unittest.main()
