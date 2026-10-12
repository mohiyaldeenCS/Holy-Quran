from __future__ import annotations

import os
import sqlite3
import struct
import tempfile
import unittest
from contextlib import closing
from unittest import mock

from hqpack import database
from hqpack.database import (
    APPLICATION_ID,
    AyahRow,
    SurahRow,
    read_stored_texts,
    require_sqlite,
    write_text_database,
)
from hqpack.errors import PackError

# Plainly synthetic text that any trimming, normalising or re-encoding would
# change. Never Quran text.
_ARABIC = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"
_DECOMPOSED = "Synthetic e\u0301 two"
_PRECOMPOSED = "Synthetic \u00e9 two"

_SURAHS = [
    SurahRow(
        number=1,
        name="Synthetic surah one",
        revelation_place="makki",
        revelation_order=2,
        basmala="Synthetic opening line",
        ayat=[
            AyahRow(1, "Synthetic ayah one", [(0, 9), (10, 14), (15, 18)], []),
            AyahRow(2, _DECOMPOSED, [(0, 9), (10, 12), (13, 16)], []),
            AyahRow(3, _PRECOMPOSED, [(0, 9), (10, 11), (12, 15)], []),
            AyahRow(4, " " + _ARABIC + "  ", [(1, 3), (4, 10)], []),
        ],
    ),
    SurahRow(
        number=2,
        name="  Synthetic  surah  two ",
        revelation_place="madani",
        revelation_order=1,
        basmala=None,
        ayat=[
            AyahRow(1, "Synthetic  double  spaces", [(0, 9), (11, 17), (19, 25)], []),
            AyahRow(2, "ab \U0001F600 cd \u06d6", [(0, 2), (6, 8)], [(1, 3, 5), (2, 9, 10)]),
        ],
    ),
    SurahRow(
        number=3,
        name="Synthetic surah three",
        revelation_place=None,
        revelation_order=None,
        basmala="",
        ayat=[AyahRow(1, "\u06da Synthetic last", [(2, 11), (12, 16)], [(0, 0, 1)])],
    ),
]
_DIVISIONS = [
    ("juz", 1, 1, 1),
    ("hizb", 1, 1, 1),
    ("rub", 1, 1, 1),
    ("rub", 2, 2, 1),
    ("page", 1, 1, 1),
    ("page", 2, 3, 1),
]
_SAJDAS = [(1, 2), (2, 2)]

# test/integrity/pack_integrity_suite.dart, `_schema`, in the RawColumn form
# `name type[ NOT NULL][ pkN]`.
_EXPECTED_SCHEMA = {
    "ayah": (
        True,
        ["surah INTEGER NOT NULL pk1", "number INTEGER NOT NULL pk2", "text TEXT NOT NULL"],
    ),
    "division": (
        True,
        [
            "kind TEXT NOT NULL pk1",
            "number INTEGER NOT NULL pk2",
            "surah INTEGER NOT NULL",
            "ayah INTEGER NOT NULL",
        ],
    ),
    "mark": (
        True,
        [
            "surah INTEGER NOT NULL pk1",
            "ayah INTEGER NOT NULL pk2",
            "number INTEGER NOT NULL pk3",
            "after_word INTEGER NOT NULL",
            "start_offset INTEGER NOT NULL",
            "end_offset INTEGER NOT NULL",
        ],
    ),
    "sajda": (True, ["surah INTEGER NOT NULL pk1", "ayah INTEGER NOT NULL pk2"]),
    "surah": (
        False,
        [
            "number INTEGER pk1",
            "name TEXT NOT NULL",
            "ayah_count INTEGER NOT NULL",
            "revelation_place TEXT",
            "revelation_order INTEGER",
            "basmala TEXT",
        ],
    ),
    "word": (
        True,
        [
            "surah INTEGER NOT NULL pk1",
            "ayah INTEGER NOT NULL pk2",
            "number INTEGER NOT NULL pk3",
            "start_offset INTEGER NOT NULL",
            "end_offset INTEGER NOT NULL",
        ],
    ),
}


class _TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = os.path.join(self._tmp.name, "a dir with spaces")
        os.mkdir(self.dir)
        self.path = os.path.join(self.dir, "text.sqlite")

    def assert_no_file_left(self):
        self.assertEqual(os.listdir(self.dir), [])


class WrittenDatabaseTest(_TempDirTest):
    def setUp(self):
        super().setUp()
        write_text_database(self.path, _SURAHS, _DIVISIONS, _SAJDAS)
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
        self.assertEqual(self._u32(60), 1)
        self.assertEqual(self._u32(68), APPLICATION_ID)
        self.assertEqual(self._u32(68).to_bytes(4, "big"), b"HQPK")
        self.assertEqual(self._u32(36), 0)

    def test_leaves_only_the_database(self):
        self.assertEqual(os.listdir(self.dir), ["text.sqlite"])

    def test_tables_are_strict_with_the_right_rowid_flag(self):
        rows = self._query(
            "SELECT name, strict, wr FROM pragma_table_list WHERE schema = 'main' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )
        self.assertEqual(
            rows,
            [(name, 1, int(wr)) for name, (wr, _) in sorted(_EXPECTED_SCHEMA.items())],
        )

    def test_tables_are_created_in_the_format_order(self):
        rows = self._query("SELECT name FROM sqlite_schema WHERE type = 'table' ORDER BY rowid")
        self.assertEqual(
            [name for (name,) in rows],
            ["surah", "ayah", "word", "mark", "division", "sajda"],
        )

    def test_columns_match_the_integrity_suite(self):
        for table, (_, expected) in _EXPECTED_SCHEMA.items():
            rows = self._query(
                'SELECT name, type, "notnull", pk, hidden FROM pragma_table_xinfo(?) '
                "ORDER BY cid",
                (table,),
            )
            self.assertTrue(all(hidden == 0 for *_, hidden in rows), table)
            found = [
                "%s %s%s%s"
                % (name, kind, " NOT NULL" if notnull else "", " pk%d" % pk if pk else "")
                for name, kind, notnull, pk, _ in rows
            ]
            self.assertEqual(found, expected, table)

    def test_stored_texts_round_trip_byte_for_byte(self):
        stored = read_stored_texts(self.path)
        self.assertEqual(stored.names, {s.number: s.name.encode("utf-8") for s in _SURAHS})
        self.assertEqual(
            stored.basmalas,
            {1: b"Synthetic opening line", 2: None, 3: b""},
        )
        self.assertEqual(
            stored.ayat,
            {(s.number, a.number): a.text.encode("utf-8") for s in _SURAHS for a in s.ayat},
        )
        self.assertNotEqual(stored.ayat[(1, 2)], stored.ayat[(1, 3)])
        self.assertIn(b"e\xcc\x81", stored.ayat[(1, 2)])
        self.assertIn(b"\xc3\xa9", stored.ayat[(1, 3)])
        self.assertIn("\U0001F600".encode("utf-8"), stored.ayat[(2, 2)])

    def test_text_columns_hold_text(self):
        rows = self._query("SELECT DISTINCT typeof(text) FROM ayah")
        self.assertEqual(rows, [("text",)])

    def test_rows(self):
        self.assertEqual(
            self._query("SELECT number, ayah_count, revelation_place, revelation_order FROM surah"),
            [(1, 4, "makki", 2), (2, 2, "madani", 1), (3, 1, None, None)],
        )
        self.assertEqual(
            self._query("SELECT * FROM word WHERE surah = 2 AND ayah = 2 ORDER BY number"),
            [(2, 2, 1, 0, 2), (2, 2, 2, 6, 8)],
        )
        self.assertEqual(
            self._query("SELECT * FROM mark ORDER BY surah, ayah, number"),
            [(2, 2, 1, 1, 3, 5), (2, 2, 2, 2, 9, 10), (3, 1, 1, 0, 0, 1)],
        )
        self.assertEqual(
            self._query("SELECT kind, number, surah, ayah FROM division ORDER BY kind, number"),
            sorted(_DIVISIONS),
        )
        self.assertEqual(self._query("SELECT * FROM sajda ORDER BY surah, ayah"), _SAJDAS)

    def test_integrity_and_foreign_keys(self):
        self.assertEqual(self._query("PRAGMA integrity_check"), [("ok",)])
        self.assertEqual(self._query("PRAGMA foreign_key_check"), [])

    def test_refuses_an_existing_path(self):
        before = os.path.getsize(self.path)
        with self.assertRaises(PackError):
            write_text_database(self.path, _SURAHS, _DIVISIONS, _SAJDAS)
        self.assertEqual(os.path.getsize(self.path), before)


class RefusalTest(_TempDirTest):
    def test_a_division_pointing_at_a_missing_ayah_leaves_no_file(self):
        with self.assertRaises(PackError) as caught:
            write_text_database(self.path, _SURAHS, _DIVISIONS + [("juz", 2, 2, 9)], _SAJDAS)
        self.assertIn("division juz 2", str(caught.exception))
        self.assertTrue(str(caught.exception).isascii())
        self.assert_no_file_left()

    def test_foreign_key_check_names_the_orphan(self):
        # With enforcement off the insert succeeds, so the final check is
        # what stops the build.
        real_run = database._run

        def run(db, sql, step, parameters=()):
            if sql == "PRAGMA foreign_keys = ON":
                sql = "PRAGMA foreign_keys = OFF"
            return real_run(db, sql, step, parameters)

        with mock.patch.object(database, "_run", run):
            with self.assertRaises(PackError) as caught:
                write_text_database(self.path, _SURAHS, _DIVISIONS, _SAJDAS + [(3, 7)])
        self.assertIn("sajda at 3:7", str(caught.exception))
        self.assert_no_file_left()

    def test_a_lone_surrogate_leaves_no_file(self):
        surah = SurahRow(1, "Synthetic", None, None, None, [AyahRow(1, "ab\ud800", [(0, 3)], [])])
        with self.assertRaises(PackError) as caught:
            write_text_database(self.path, [surah], [], [])
        self.assertIn("ayah 1:1", str(caught.exception))
        self.assert_no_file_left()

    def test_a_leading_byte_order_mark_is_refused_not_stripped(self):
        surah = SurahRow(1, "Synthetic", None, None, "\ufeffSynthetic", [AyahRow(1, "ab", [(0, 2)], [])])
        with self.assertRaises(PackError) as caught:
            write_text_database(self.path, [surah], [], [])
        self.assertIn("surah 1 basmala begins with U+FEFF", str(caught.exception))
        self.assert_no_file_left()

    def test_an_unknown_revelation_place_names_no_value(self):
        surah = SurahRow(1, "Synthetic", "Synthetic-place", None, None, [AyahRow(1, "ab", [(0, 2)], [])])
        with self.assertRaises(PackError) as caught:
            write_text_database(self.path, [surah], [], [])
        self.assertNotIn("Synthetic", str(caught.exception))
        self.assert_no_file_left()

    def test_reading_a_missing_file_raises(self):
        with self.assertRaises(PackError):
            read_stored_texts(self.path)


class RequireSqliteTest(unittest.TestCase):
    def test_returns_the_version(self):
        self.assertEqual(require_sqlite(), sqlite3.sqlite_version)

    def test_refuses_a_version_below_3_37(self):
        with mock.patch.object(database.sqlite3, "sqlite_version", "3.36.9"):
            with self.assertRaises(PackError) as caught:
                require_sqlite()
        self.assertIn("3.36.9", str(caught.exception))

    def test_accepts_3_37_0(self):
        with mock.patch.object(database.sqlite3, "sqlite_version", "3.37.0"):
            self.assertEqual(require_sqlite(), "3.37.0")


if __name__ == "__main__":
    unittest.main()
