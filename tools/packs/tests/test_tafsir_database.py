"""`tafsir.sqlite`: header, schema, stored bytes, the surah-level passage and refusals."""

from __future__ import annotations

import os
import sqlite3
import struct
import tempfile
import unittest
from contextlib import closing

from hqpack.database import APPLICATION_ID
from hqpack.errors import PackError
from hqpack.tafsir_database import (
    SURAH_LEVEL,
    BookFacts,
    PassageRow,
    read_tafsir_texts,
    write_tafsir_database,
)

# Plainly synthetic text that any trimming, normalising or re-encoding would
# change. Never Quran or book text.
_ARABIC = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"
_DECOMPOSED = "Synthetic e\u0301 passage"
_PRECOMPOSED = "Synthetic \u00e9 passage"

_BOOK = BookFacts(
    title="Synthetic title " + _ARABIC,
    author="Synthetic author",
    publisher="Synthetic publisher",
    edition=None,
    editor=None,
)
_PASSAGES = [
    PassageRow(1, 1, SURAH_LEVEL, SURAH_LEVEL, "Synthetic surah-level line one\nline two"),
    PassageRow(2, 1, 1, 2, _DECOMPOSED),
    PassageRow(3, 1, 3, 3, _PRECOMPOSED),
    PassageRow(4, 2, 1, 4, "  " + _ARABIC + " \ufdfa  "),
]

# lib/data/services/tafsir_pack_database.dart, `_schemas[2]`: name, type,
# notnull, pk.
_APP_SCHEMA = {
    "book": [
        ("title", "TEXT", 1, 0),
        ("author", "TEXT", 1, 0),
        ("publisher", "TEXT", 0, 0),
        ("edition", "TEXT", 0, 0),
        ("editor", "TEXT", 0, 0),
    ],
    "passage": [
        ("number", "INTEGER", 0, 1),
        ("surah", "INTEGER", 1, 0),
        ("first_ayah", "INTEGER", 1, 0),
        ("last_ayah", "INTEGER", 1, 0),
        ("text", "TEXT", 1, 0),
    ],
}


class _TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = os.path.join(self._tmp.name, "a dir with spaces")
        os.mkdir(self.dir)
        self.path = os.path.join(self.dir, "tafsir.sqlite")

    def assert_no_file_left(self):
        self.assertEqual(os.listdir(self.dir), [])

    def assert_refused(self, book, passages, expected):
        with self.assertRaises(PackError) as caught:
            write_tafsir_database(self.path, book, passages)
        message = str(caught.exception)
        self.assertIn(expected, message)
        self.assertTrue(message.isascii(), message)
        self.assertNotIn("Synthetic", message)
        self.assert_no_file_left()


class WrittenTafsirTest(_TempDirTest):
    def setUp(self):
        super().setUp()
        write_tafsir_database(self.path, _BOOK, _PASSAGES)
        with open(self.path, "rb") as f:
            self.header = f.read(100)

    def _query(self, sql, parameters=()):
        with closing(sqlite3.connect(self.path)) as db:
            return db.execute(sql, parameters).fetchall()

    def _u32(self, offset):
        return struct.unpack(">I", self.header[offset : offset + 4])[0]

    def test_header(self):
        self.assertEqual(self.header[:16], b"SQLite format 3\x00")
        self.assertEqual((self.header[18], self.header[19]), (1, 1))
        self.assertEqual(self._u32(56), 1)
        self.assertEqual(self._u32(60), 2)
        self.assertEqual(self._u32(68), APPLICATION_ID)
        self.assertEqual(self._u32(36), 0)

    def test_leaves_only_the_database(self):
        self.assertEqual(os.listdir(self.dir), ["tafsir.sqlite"])

    def test_the_tables_are_the_apps_in_order_and_strict(self):
        self.assertEqual(
            self._query("SELECT name FROM sqlite_schema WHERE type = 'table' ORDER BY rowid"),
            [("book",), ("passage",)],
        )
        self.assertEqual(
            self._query(
                "SELECT name, strict, wr FROM pragma_table_list WHERE schema = 'main' "
                "AND name NOT LIKE 'sqlite_%' ORDER BY name"
            ),
            [("book", 1, 0), ("passage", 1, 0)],
        )
        for table, expected in _APP_SCHEMA.items():
            rows = self._query(
                'SELECT name, type, "notnull", pk, hidden FROM pragma_table_xinfo(?) ORDER BY cid',
                (table,),
            )
            self.assertEqual(rows, [column + (0,) for column in expected], table)
        self.assertEqual(
            self._query("SELECT type, name FROM sqlite_schema WHERE type != 'table'"),
            [("index", "sqlite_autoindex_passage_1")],
        )

    def test_texts_read_back_byte_for_byte(self):
        stored = read_tafsir_texts(self.path)
        self.assertEqual(
            stored.book,
            {
                "title": _BOOK.title.encode("utf-8"),
                "author": b"Synthetic author",
                "publisher": b"Synthetic publisher",
                "edition": None,
                "editor": None,
            },
        )
        self.assertEqual(stored.passages, {p.number: p.text.encode("utf-8") for p in _PASSAGES})
        self.assertIn(b"e\xcc\x81", stored.passages[2])
        self.assertIn(b"\xc3\xa9", stored.passages[3])
        self.assertIn(b"\n", stored.passages[1])
        self.assertTrue(stored.passages[4].startswith(b"  ") and stored.passages[4].endswith(b"  "))

    def test_rows_and_the_surah_level_range(self):
        self.assertEqual(
            self._query("SELECT number, surah, first_ayah, last_ayah, typeof(text) FROM passage ORDER BY number"),
            [(1, 1, 0, 0, "text"), (2, 1, 1, 2, "text"), (3, 1, 3, 3, "text"), (4, 2, 1, 4, "text")],
        )
        self.assertEqual(self._query("SELECT typeof(edition), typeof(editor) FROM book"), [("null", "null")])

    def test_the_file_itself_refuses_a_range_outside_the_rule(self):
        for surah, first, last in ((3, 0, 2), (3, 2, 0), (3, 2, 1), (3, -1, 1), (0, 1, 1), (1, 0, 0)):
            with self.subTest(range=(surah, first, last)):
                with closing(sqlite3.connect(self.path)) as db:
                    with self.assertRaises(sqlite3.IntegrityError):
                        db.execute(
                            "INSERT INTO passage VALUES (99, ?, ?, ?, 'x')", (surah, first, last)
                        )

    def test_refuses_an_existing_path(self):
        before = os.path.getsize(self.path)
        with self.assertRaises(PackError) as caught:
            write_tafsir_database(self.path, _BOOK, _PASSAGES)
        self.assertEqual(str(caught.exception), "tafsir.sqlite: the output path already exists")
        self.assertEqual(os.path.getsize(self.path), before)


class RefusalTest(_TempDirTest):
    def test_a_second_surah_level_passage_in_one_surah(self):
        extra = PassageRow(5, 1, SURAH_LEVEL, SURAH_LEVEL, "Synthetic again")
        self.assert_refused(_BOOK, _PASSAGES + [extra], "inserting passage 5 (surah 1, ayat 0..0) failed")

    def test_a_range_that_is_neither_surah_level_nor_from_ayah_one(self):
        for first, last in ((0, 3), (3, 0), (4, 3), (-1, 2)):
            with self.subTest(range=(first, last)):
                passage = PassageRow(5, 3, first, last, "Synthetic")
                self.assert_refused(_BOOK, _PASSAGES + [passage], "inserting passage 5 (surah 3")

    def test_surah_zero(self):
        self.assert_refused(_BOOK, [PassageRow(1, 0, 1, 1, "Synthetic")], "inserting passage 1 (surah 0")

    def test_a_repeated_number(self):
        self.assert_refused(_BOOK, _PASSAGES + [PassageRow(4, 3, 1, 1, "Synthetic")], "inserting passage 4")

    def test_a_leading_byte_order_mark_is_refused_not_stripped(self):
        self.assert_refused(
            _BOOK, [PassageRow(1, 1, 1, 1, "\ufeffSynthetic")], "passage 1 begins with U+FEFF"
        )
        self.assert_refused(
            BookFacts("Synthetic", "Synthetic", "\ufeffSynthetic", None, None),
            _PASSAGES,
            "book.publisher begins with U+FEFF",
        )

    def test_a_lone_surrogate(self):
        self.assert_refused(_BOOK, [PassageRow(1, 1, 1, 1, "ab\ud800")], "passage 1 holds a lone surrogate")

    def test_a_null_title_or_author(self):
        self.assert_refused(BookFacts(None, "Synthetic", None, None, None), _PASSAGES, "book.title is not a string")
        self.assert_refused(BookFacts("Synthetic", None, None, None, None), _PASSAGES, "book.author is not a string")

    def test_a_number_that_is_not_an_integer(self):
        self.assert_refused(_BOOK, [PassageRow(1, 1, True, 1, "Synthetic")], "first_ayah is not an integer")

    def test_no_passage(self):
        self.assert_refused(_BOOK, [], "tafsir.sqlite: there is no passage")

    def test_reading_a_missing_file_raises(self):
        with self.assertRaises(PackError):
            read_tafsir_texts(self.path)


if __name__ == "__main__":
    unittest.main()
